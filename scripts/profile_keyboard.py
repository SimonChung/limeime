#!/usr/bin/env python3
"""
profile_keyboard.py — Stroke-to-stroke latency harness for LimeKeyboard.

Drives an XCUITest fixture (`StrokeBenchmark`) against the LimeKeyboard
extension, records an Instruments trace via `xctrace`, extracts the
`os_signpost` intervals embedded in production code (see
docs/IOS_PROFILING.md §2), and reports per-IM medians/p95s for each
segment of the stroke pipeline.

Optionally fails (non-zero exit) when any segment's p95 regresses past
a threshold relative to scripts/profile_baseline.json.

Usage:
    python3 scripts/profile_keyboard.py --device 'iPhone 15 Pro'
    python3 scripts/profile_keyboard.py --device 'iPhone 15 Pro' --ci
    python3 scripts/profile_keyboard.py --device 'iPhone 15 Pro' \
        --update-baseline

Limitations:
    - Simulator timings are directional only; reserve real-device runs
      for absolute truth.
    - First stroke per IM is dropped before computing percentiles
      (cold DB-open, font cache fill).
    - Requires Xcode 15+ for `xctrace export --xpath`.

This script is the *measurement* loop only. It does NOT decide which
hot spot to fix, apply optimisations, or update the baseline
automatically — those steps require human review.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from statistics import median
from typing import Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "build" / "profile"
BASELINE = REPO_ROOT / "scripts" / "profile_baseline.json"
WORKSPACE = REPO_ROOT / "LimeIME-iOS" / "LimeIME.xcodeproj"
# Build scheme — the host app scheme that embeds the LimeKeyboard
# extension. UI tests are launched separately by `xcodebuild test`
# against the UI-test scheme below.
SCHEME = "LimeIME"
# UI-test scheme + class name. Created via Xcode → New Target →
# UI Testing Bundle (see docs/IOS_PROFILING.md §9.3).
UI_TEST_SCHEME = "LimeUITests"
TEST_TARGET = "LimeUITests/StrokeBenchmark"

# Segments tracked. Must match the os_signpost names in production code
# (see docs/IOS_PROFILING.md §2.3).
SEGMENTS = [
    "Stroke",
    "ComposingPopup",
    "DBQueryStage1",
    "DBQueryStage2",
    "CandidateReload",
    "CandidateSwap",
]

# Per-IM test methods inside StrokeBenchmark.
IM_TESTS = ["testPhonetic", "testCangjie", "testArray"]

# Default reference device for stroke profiling. Override with --device.
# Pinned to iPad Pro 13-inch (M5) so traces are comparable across runs.
DEFAULT_DEVICE = "iPad Pro 13-inch (M5)"

# CI regression threshold: fail when p95 exceeds baseline × this factor.
REGRESSION_FACTOR = 1.20


# --------------------------------------------------------------------------- #
# Shell helpers
# --------------------------------------------------------------------------- #

def run(cmd: List[str], *, check: bool = True,
        capture: bool = False) -> subprocess.CompletedProcess:
    """Run a shell command and stream output unless capture=True."""
    print(f"$ {' '.join(cmd)}", flush=True)
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        capture_output=capture,
    )


def require(tool: str) -> None:
    if shutil.which(tool) is None:
        sys.exit(f"error: required tool `{tool}` not on PATH")


# --------------------------------------------------------------------------- #
# Build / record / export pipeline
# --------------------------------------------------------------------------- #

def build_for_testing(device_id: str) -> None:
    run([
        "xcodebuild",
        "-project", str(WORKSPACE),
        "-scheme", SCHEME,
        "-destination", f"id={device_id}",
        "-configuration", "Debug",
        "build-for-testing",
    ])


def record_trace(device_id: str, trace_path: Path,
                 test_method: str) -> None:
    """Run one XCUITest method under xctrace recording."""
    trace_path.parent.mkdir(parents=True, exist_ok=True)
    if trace_path.exists():
        shutil.rmtree(trace_path)

    # xctrace launches the test process itself when --launch is used; for
    # an already-installed test we drive xcodebuild test in parallel and
    # attach by template. Simpler: use xctrace `record --launch` against
    # the test runner. Here we wrap xcodebuild test inside xctrace.
    run([
        "xcrun", "xctrace", "record",
        "--template", "Time Profiler",
        "--output", str(trace_path),
        "--time-limit", "30s",
        "--target-stdout", "-",
        "--launch", "--",
        "xcodebuild",
        "-project", str(WORKSPACE),
        "-scheme", UI_TEST_SCHEME,
        "-destination", f"id={device_id}",
        "-only-testing:" + f"{TEST_TARGET}/{test_method}",
        "test-without-building",
    ])


def export_signposts(trace_path: Path, xml_path: Path) -> None:
    run([
        "xcrun", "xctrace", "export",
        "--input", str(trace_path),
        "--xpath", "/trace-toc/run/data/table[@schema='os-signpost']",
        "--output", str(xml_path),
    ])


# --------------------------------------------------------------------------- #
# Signpost parsing
# --------------------------------------------------------------------------- #

@dataclass
class Stats:
    samples: List[float] = field(default_factory=list)

    def add(self, ms: float) -> None:
        self.samples.append(ms)

    def median(self) -> float:
        return median(self.samples) if self.samples else 0.0

    def p95(self) -> float:
        if not self.samples:
            return 0.0
        ordered = sorted(self.samples)
        idx = max(0, int(round(0.95 * (len(ordered) - 1))))
        return ordered[idx]

    def count(self) -> int:
        return len(self.samples)


def parse_signposts(xml_path: Path,
                    drop_first: bool = True) -> Dict[str, Stats]:
    """
    Parse an xctrace XML export and return {segment_name: Stats}.

    The schema for `os-signpost` rows in xctrace XML typically has child
    elements with attributes `name`, `event-type` (begin/end/event), and
    `start` (in nanoseconds). We pair begins with ends by signpost-id
    when available, otherwise by FIFO per name.
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Each row carries: name, signpost-id, event-type, start (ns).
    # Schema differs across Xcode versions; this parser is defensive.
    open_intervals: Dict[str, List[float]] = {n: [] for n in SEGMENTS}
    stats: Dict[str, Stats] = {n: Stats() for n in SEGMENTS}

    for row in root.iter("row"):
        name = _attr(row, "name")
        if name not in SEGMENTS:
            continue
        evt = _attr(row, "event-type")
        start_ns = _float_attr(row, "start")
        if start_ns is None:
            continue
        if evt == "begin":
            open_intervals[name].append(start_ns)
        elif evt == "end" and open_intervals[name]:
            begin_ns = open_intervals[name].pop(0)
            ms = (start_ns - begin_ns) / 1_000_000.0
            stats[name].add(ms)

    if drop_first:
        for s in stats.values():
            if s.samples:
                s.samples = s.samples[1:]

    return stats


def _attr(elem: ET.Element, name: str) -> str:
    """Find an attribute either on the element or in a child <attribute>."""
    if name in elem.attrib:
        return elem.attrib[name]
    for child in elem:
        if child.tag == name:
            return (child.text or "").strip()
        if child.attrib.get("name") == name:
            return (child.text or child.attrib.get("value") or "").strip()
    return ""


def _float_attr(elem: ET.Element, name: str) -> Optional[float]:
    raw = _attr(elem, name)
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


# --------------------------------------------------------------------------- #
# Reporting / baseline
# --------------------------------------------------------------------------- #

def load_baseline() -> Dict[str, Dict[str, Dict[str, float]]]:
    if BASELINE.exists():
        return json.loads(BASELINE.read_text())
    return {}


def write_baseline(report: Dict[str, Dict[str, Stats]]) -> None:
    out = {
        im: {
            seg: {"median_ms": round(stats.median(), 3),
                  "p95_ms": round(stats.p95(), 3),
                  "n": stats.count()}
            for seg, stats in segs.items()
        }
        for im, segs in report.items()
    }
    BASELINE.write_text(json.dumps(out, indent=2) + "\n")
    print(f"\nBaseline written to {BASELINE.relative_to(REPO_ROOT)}")


def print_report(report: Dict[str, Dict[str, Stats]],
                 baseline: Dict[str, Dict[str, Dict[str, float]]],
                 ci: bool) -> int:
    """Print a table; return number of regressions detected."""
    header = f"{'IM':<10}{'segment':<18}{'median':>9}{'p95':>9}" \
             f"{'baseline_p95':>15}{'delta':>9}  status"
    print()
    print(header)
    print("-" * len(header))

    regressions = 0
    for im, segs in report.items():
        base_im = baseline.get(im, {})
        for seg in SEGMENTS:
            stats = segs[seg]
            if stats.count() == 0:
                continue
            base_p95 = base_im.get(seg, {}).get("p95_ms")
            delta_str = "    -"
            status = "ok"
            if base_p95 and base_p95 > 0:
                delta = (stats.p95() - base_p95) / base_p95
                delta_str = f"{delta * 100:+.0f}%"
                if delta > (REGRESSION_FACTOR - 1.0):
                    status = "FAIL"
                    regressions += 1
            print(f"{im:<10}{seg:<18}"
                  f"{stats.median():>7.1f}ms"
                  f"{stats.p95():>7.1f}ms"
                  f"{(base_p95 or 0):>13.1f}ms"
                  f"{delta_str:>9}  {status}")

    print()
    if ci:
        if regressions:
            print(f"Result: {regressions} regression(s) "
                  f"(threshold +{int((REGRESSION_FACTOR - 1) * 100)}%).")
        else:
            print("Result: no regressions.")
    return regressions


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--device", default=DEFAULT_DEVICE,
                   help=f"Simulator/device UDID or name. "
                        f"Default: {DEFAULT_DEVICE!r}.")
    p.add_argument("--ci", action="store_true",
                   help="Exit non-zero on any p95 regression > +20%%.")
    p.add_argument("--update-baseline", action="store_true",
                   help="Overwrite scripts/profile_baseline.json with this run.")
    p.add_argument("--skip-build", action="store_true",
                   help="Reuse the previous build-for-testing artefacts.")
    args = p.parse_args()

    require("xcodebuild")
    require("xcrun")

    device_id = resolve_device(args.device)
    print(f"Using device: {device_id}")

    if not args.skip_build:
        build_for_testing(device_id)
        # Also build-for-testing the UI-test scheme so xctrace's
        # `test-without-building` step can launch immediately.
        run([
            "xcodebuild",
            "-project", str(WORKSPACE),
            "-scheme", UI_TEST_SCHEME,
            "-destination", f"id={device_id}",
            "-configuration", "Debug",
            "build-for-testing",
        ])

    report: Dict[str, Dict[str, Stats]] = {}

    for test_method in IM_TESTS:
        im_label = test_method.replace("test", "").lower()
        trace_path = BUILD_DIR / f"{im_label}.trace"
        xml_path = BUILD_DIR / f"{im_label}.xml"
        record_trace(device_id, trace_path, test_method)
        export_signposts(trace_path, xml_path)
        report[im_label] = parse_signposts(xml_path)

    baseline = load_baseline()
    regressions = print_report(report, baseline, ci=args.ci)

    if args.update_baseline:
        write_baseline(report)

    if args.ci and regressions:
        return 1
    return 0


def resolve_device(device: str) -> str:
    """Accept either a UDID or a simulator display name."""
    # If it already looks like a UDID, pass through.
    if len(device) >= 25 and "-" in device:
        return device
    # Otherwise look it up via simctl.
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "--json"],
        check=True, text=True, capture_output=True,
    ).stdout
    data = json.loads(out)
    for runtime, devices in data.get("devices", {}).items():
        for d in devices:
            if d.get("name") == device and d.get("isAvailable"):
                return d["udid"]
    sys.exit(f"error: no available simulator named '{device}'")


if __name__ == "__main__":
    sys.exit(main())
