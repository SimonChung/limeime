#!/usr/bin/env python3
"""
Inventory hardcoded UI colors and layout metrics in LIME iOS/Android sources.

Usage:
  python3 scripts/check_ui_theme_literals.py
  python3 scripts/check_ui_theme_literals.py --fail-on high
  python3 scripts/check_ui_theme_literals.py --write-baseline scripts/ui_theme_literal_baseline.json

The script is intentionally conservative: it reports suspicious literals first,
then lets maintainers centralize valid constants or allowlist intentional cases.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import re
from collections import Counter
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = Path(__file__).with_name("ui_theme_literal_baseline.json")

SCAN_ROOTS = [
    ROOT / "LimeIME-iOS",
    ROOT / "LimeStudio" / "app" / "src" / "main",
]

SKIP_PARTS = {
    ".git",
    ".Codex",
    "build",
    "DerivedData",
    ".build",
    "Pods",
    "LimeTests",
    "LimeUITests",
    "androidTest",
    "test",
}

SOURCE_SUFFIXES = {".swift", ".java", ".kt", ".xml"}


@dataclasses.dataclass(frozen=True)
class Finding:
    severity: str
    kind: str
    path: Path
    line: int
    text: str
    reason: str


HIGH_SWIFT_COLOR_PATTERNS = [
    (re.compile(r"\.(foregroundColor|foregroundStyle|tint|accentColor)\s*\(\s*\.(white|black|gray|red|green|blue)\b"), "hardcoded SwiftUI foreground/icon color"),
    (re.compile(r"\b(Color|UIColor)\.(white|black|gray|red|green|blue)\b"), "hardcoded Swift color constant"),
    (re.compile(r"\bUIColor\s*\(\s*(red|white|displayP3Red)\s*:"), "literal UIColor constructor"),
]

HIGH_ANDROID_COLOR_PATTERNS = [
    (re.compile(r"\bColor\.(WHITE|BLACK|GRAY|RED|GREEN|BLUE)\b"), "hardcoded Android Color constant"),
    (re.compile(r"\bset(TextColor|BackgroundColor|Tint)\s*\("), "programmatic Android UI color setter"),
    (re.compile(r'android:(textColor|background|tint|fillColor)\s*=\s*"#[0-9A-Fa-f]{6,8}"'), "hardcoded Android XML UI color"),
]

MEDIUM_COLOR_PATTERNS = [
    (re.compile(r"#[0-9A-Fa-f]{6,8}"), "raw hex color literal"),
]

SWIFT_METRIC_PATTERNS = [
    (re.compile(r"\.(padding|cornerRadius)\s*\(\s*[0-9]+(?:\.[0-9]+)?"), "hardcoded SwiftUI spacing/radius"),
    (re.compile(r"\.frame\s*\([^)]*\b(width|height|minWidth|minHeight|maxWidth|maxHeight)\s*:\s*[0-9]+(?:\.[0-9]+)?"), "hardcoded SwiftUI frame metric"),
    (re.compile(r"\.font\s*\(\s*\.system\s*\(\s*size\s*:\s*[0-9]+(?:\.[0-9]+)?"), "hardcoded SwiftUI font size"),
    (re.compile(r"\bUIFont\.systemFont\s*\(\s*ofSize\s*:\s*[0-9]+(?:\.[0-9]+)?"), "hardcoded UIKit font size"),
]

ANDROID_METRIC_PATTERNS = [
    (re.compile(r'android:(width|height|layout_width|layout_height|padding[^=]*|layout_margin[^=]*|textSize|radius)\s*=\s*"[0-9.]+(?:dp|dip|sp)"'), "hardcoded Android XML metric"),
    (re.compile(r"\bset(Padding|TextSize|MinHeight|MinimumHeight|MinimumWidth)\s*\([^)]*[0-9]+"), "programmatic Android UI metric"),
]


def is_central_resource(path: Path) -> bool:
    parts = set(path.parts)
    name = path.name
    if name in {"LayoutMetrics.swift"}:
        return True
    if name.endswith("Theme.swift") or name.endswith("Metrics.swift"):
        return True
    if "res" in parts and "values" in parts:
        return name in {"colors.xml", "dimens.xml", "styles.xml", "themes.xml"}
    if "res" in parts and name.startswith("btn_flat_keyboard_"):
        return True
    if "res" in parts and name.startswith("keyboard_"):
        return True
    return False


def is_generated_or_vendor(path: Path) -> bool:
    rel_parts = set(path.relative_to(ROOT).parts)
    if rel_parts & SKIP_PARTS:
        return True
    if "aidl" in rel_parts:
        return True
    return False


def iter_files() -> Iterable[Path]:
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
                continue
            if is_generated_or_vendor(path):
                continue
            yield path


def strip_comment_noise(line: str, suffix: str) -> str:
    if suffix in {".swift", ".java", ".kt"}:
        return line.split("//", 1)[0]
    if "<!--" in line:
        return line.split("<!--", 1)[0]
    return line


def scan_line(path: Path, line_no: int, line: str) -> list[Finding]:
    code = strip_comment_noise(line, path.suffix)
    if not code.strip():
        return []

    findings: list[Finding] = []
    rel = path.relative_to(ROOT)
    central = is_central_resource(path)

    if path.suffix == ".swift":
        color_severity = "info" if central else "high"
        metric_severity = "info" if central else "medium"
        for pattern, reason in HIGH_SWIFT_COLOR_PATTERNS:
            if pattern.search(code):
                findings.append(Finding(color_severity, "color", rel, line_no, code.strip(), reason))
        for pattern, reason in SWIFT_METRIC_PATTERNS:
            if pattern.search(code):
                findings.append(Finding(metric_severity, "metric", rel, line_no, code.strip(), reason))

    if path.suffix in {".java", ".kt", ".xml"}:
        color_severity = "info" if central else "high"
        metric_severity = "info" if central else "medium"
        for pattern, reason in HIGH_ANDROID_COLOR_PATTERNS:
            if pattern.search(code):
                findings.append(Finding(color_severity, "color", rel, line_no, code.strip(), reason))
        for pattern, reason in ANDROID_METRIC_PATTERNS:
            if pattern.search(code):
                findings.append(Finding(metric_severity, "metric", rel, line_no, code.strip(), reason))

    color_severity = "info" if central else "medium"
    for pattern, reason in MEDIUM_COLOR_PATTERNS:
        if pattern.search(code):
            findings.append(Finding(color_severity, "color", rel, line_no, code.strip(), reason))

    return findings


def scan() -> list[Finding]:
    findings: list[Finding] = []
    for path in iter_files():
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="replace")
        for index, line in enumerate(text.splitlines(), start=1):
            findings.extend(scan_line(path, index, line))
    return findings


def should_fail(findings: list[Finding], mode: str) -> bool:
    if mode == "none":
        return False
    severities = {finding.severity for finding in findings}
    if mode == "high":
        return "high" in severities
    if mode == "medium":
        return bool(severities & {"high", "medium"})
    return False


def baseline_counts(findings: list[Finding]) -> dict[str, int]:
    counts = Counter(
        f"{finding.severity}:{finding.kind}:{finding.path}"
        for finding in findings
        if finding.severity in {"high", "medium"}
    )
    return dict(sorted(counts.items()))


def write_baseline(path: Path, findings: list[Finding]) -> None:
    payload = {
        "description": "Baseline for UI theme literal guard. Reduce counts when literals are centralized.",
        "counts": baseline_counts(findings),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def baseline_regressions(path: Path, findings: list[Finding]) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    old_counts = payload.get("counts", {})
    new_counts = baseline_counts(findings)
    regressions: list[str] = []
    for key, new_count in sorted(new_counts.items()):
        old_count = int(old_counts.get(key, 0))
        if new_count > old_count:
            regressions.append(f"{key}: {old_count} -> {new_count}")
    return regressions


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fail-on", choices=["none", "high", "medium"], default="none")
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--no-baseline", action="store_true")
    parser.add_argument("--write-baseline", type=Path)
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()

    findings = scan()
    if args.write_baseline:
        write_baseline(args.write_baseline, findings)
        print(f"Wrote baseline: {args.write_baseline}")

    counts = Counter((finding.severity, finding.kind) for finding in findings)
    file_counts = Counter(finding.path for finding in findings if finding.severity in {"high", "medium"})

    print("UI literal inventory")
    print("====================")
    for key in sorted(counts):
        print(f"{key[0]:>6} {key[1]:>6}: {counts[key]}")
    print()

    print("Top risky files")
    print("---------------")
    for path, count in file_counts.most_common(20):
        print(f"{count:4} {path}")
    print()

    print(f"Findings (first {args.limit})")
    print("----------------")
    for finding in findings[: args.limit]:
        print(f"{finding.severity.upper():6} {finding.kind:6} {finding.path}:{finding.line} {finding.reason}")
        print(f"       {finding.text}")

    if not args.no_baseline and args.baseline:
        regressions = baseline_regressions(args.baseline, findings)
        if regressions:
            print()
            print("Baseline regressions")
            print("--------------------")
            for regression in regressions:
                print(regression)
            return 1

    return 1 if should_fail(findings, args.fail_on) else 0


if __name__ == "__main__":
    raise SystemExit(main())
