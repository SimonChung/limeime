//
//  StrokeBenchmark.swift
//  LimeTests
//
//  XCUITest fixture that drives a deterministic stroke sequence for each
//  IM. Pairs with `scripts/profile_keyboard.py`, which records an
//  Instruments trace around this test and parses the `os_signpost`
//  intervals emitted from production code (see docs/IOS_PROFILING.md).
//
//  IMPORTANT: This file lives in the LimeTests folder for repo-layout
//  reasons, but it is an XCUITest (`XCTestCase` driving `XCUIApplication`)
//  and therefore requires a UI-test target — NOT a unit-test target.
//  XCUITest cannot run inside a `bundle.unit-test` host.
//
//  Wiring (one-time):
//    1. Add a UI-test target to `LimeIME-iOS/project.yml` that includes
//       only this file (exclude it from the existing `LimeIMETests`
//       unit-test target):
//
//         LimeIMEUITests:
//           type: bundle.ui-testing
//           platform: iOS
//           sources:
//             - path: LimeTests
//               includes:
//                 - "StrokeBenchmark.swift"
//           dependencies:
//             - target: LimeIME      # the host app
//           settings:
//             base:
//               PRODUCT_BUNDLE_IDENTIFIER: net.toload.limeime.uitests
//               TEST_TARGET_NAME: LimeIME
//
//       And exclude it from `LimeIMETests`:
//
//         LimeIMETests:
//           sources:
//             - path: LimeTests
//               excludes:
//                 - "StrokeBenchmark.swift"
//
//    2. Re-run `xcodegen generate` and commit the new project file.
//    3. Pre-enable LimeIME in iOS Settings on the target simulator and
//       set it as the default Chinese keyboard so `typeText` routes
//       through the extension.
//
//  This fixture's only job is to generate strokes. All timing is
//  captured by signposts already embedded in production code paths.
//

import XCTest

final class StrokeBenchmark: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Per-IM tests (names referenced by profile_keyboard.py)

    func testPhonetic() throws {
        try runFixture(im: "phonetic",
                       strokes: "wo3 jiao4 li2 ming2 ")
    }

    func testCangjie() throws {
        try runFixture(im: "cj",
                       strokes: "r5,e ji jq ")
    }

    func testArray() throws {
        try runFixture(im: "array",
                       strokes: "wlw rlr ")
    }

    // MARK: - Driver

    /// Drives a deterministic stroke sequence in MobileSafari with a
    /// `data:` URL containing an autofocused `<textarea>`. Safari is
    /// chosen because:
    ///   - It is present on every iOS simulator (Notes is not in iOS
    ///     26.4 simulator runtimes).
    ///   - The `<textarea autofocus>` opens the keyboard immediately on
    ///     load with no UI walking, eliminating per-iOS-version flake.
    ///   - First-party browser → first-party keyboard extension is the
    ///     same dispatch path a real user exercises in any app.
    /// Each character is sent individually so the inter-stroke pause is
    /// not absorbed into a single batched insert; this matches a real
    /// user's typing cadence.
    private func runFixture(im: String, strokes: String) throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

        // Open the data: URL via SpringBoard's URL handler. This works
        // around iOS 26's bottom address bar layout (which moves and
        // renames the URL field every few releases) and survives the
        // post-rebuild active-keyboard reset by avoiding the URL field
        // entirely. The data: URL is small enough to fit in a single
        // openURL.
        let html = """
        <!doctype html><meta name=viewport content='width=device-width'>\
        <body style='margin:0'>\
        <textarea autofocus style='width:100vw;height:100vh;font-size:24px;border:0;outline:0'></textarea>
        """
        let dataURL = "data:text/html;charset=utf-8," +
            (html.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        try openURLViaSpringBoard(dataURL)

        // Wait for Safari to come to the foreground with the page loaded.
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10),
                      "Safari did not become foreground (im=\(im))")

        // Wait for the textarea to receive focus and the keyboard to
        // appear. The textarea is exposed as a textView in the a11y
        // tree under WebKit.
        let textArea = safari.webViews.textViews.firstMatch
        XCTAssertTrue(textArea.waitForExistence(timeout: 10),
                      "Safari textarea did not appear (im=\(im))")
        // Already autofocused, but tap to be safe.
        textArea.tap()

        // NOTE: Keyboard switching via the globe key is intentionally
        // NOT performed here on iOS 26 simulators. Querying
        // `app.keyboards.*` triggers AccessibilitySettingsLoader inside
        // the keyboard extension, which crashes (EXC_GUARD in libxpc
        // during xpc_connection_copy_bundle_id) — Apple bug specific
        // to iPad iOS 26 simulator + a custom keyboard extension under
        // XCUITest's accessibility introspection.
        //
        // Workaround: the simulator must already have LimeIME (萊姆輸入法)
        // pinned as the active keyboard for whichever input language
        // Safari is using. Set it once via Settings → General →
        // Keyboard → Keyboards → Edit → drag to top, then keep it
        // there. The fixture relies on this preconfiguration.
        //
        // If LimeIME is NOT the active keyboard at this point, the
        // strokes will simply be typed via the system keyboard and no
        // signposts will fire — the harness will report 0 samples,
        // which is the canary that this precondition was violated.

        for char in strokes {
            textArea.typeText(String(char))
            // Tiny pause so signposts from the previous stroke close
            // before the next stroke begins. Keep this small enough that
            // the trace still captures genuine inter-stroke latency.
            usleep(20_000)  // 20 ms
        }

        // Allow the stage-2 candidate swap and any deferred UI work to
        // complete so all `Stroke` signposts are closed before xctrace
        // stops recording.
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Helpers

    /// Open a URL in Safari via SpringBoard, sidestepping Safari's URL
    /// bar entirely. Uses the `x-safari-https://` scheme trick is not
    /// safe for `data:` URLs, so we go through the standard URL field
    /// in SpringBoard's app switcher path: launch via `XCUIApplication`
    /// of SpringBoard and use its private URL-open accessibility hook.
    /// Falls back to opening Safari and pasting via the URL bar if the
    /// private hook fails.
    private func openURLViaSpringBoard(_ urlString: String) throws {
        // The cleanest cross-version way: terminate Safari, then relaunch
        // it with `XCUIApplication.launch()` and use the URL field. But
        // since the URL field name changes per iOS version, prefer the
        // `XCUIDevice` system-open path via NSURL handling.
        guard let url = URL(string: urlString) else {
            XCTFail("Bad URL"); return
        }
        // XCUIRemote/XCUIDevice cannot open URLs directly. Use
        // SpringBoard's `OpenSensitiveURL:` via the private API exposed
        // through `UIApplication.shared.open(_:)` is not reachable from
        // an XCUITest process (no UIApplication). Fall back to driving
        // the Safari URL field across all known identifiers.
        try driveSafariURLBar(url.absoluteString)
    }

    /// Type a URL into Safari's address bar. Tries every known
    /// identifier across iOS 16–26 (top bar, bottom bar, tab overview).
    private func driveSafariURLBar(_ urlString: String) throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10),
                      "Safari did not foreground for URL entry")

        // Dismiss Safari's first-launch overlay if present. Xcode's
        // test clones are fresh sims, so Safari shows this on every
        // first run inside a clone.
        dismissSafariFirstLaunch(in: safari)

        // Known identifiers across iOS versions:
        //   iOS 15-:  textFields["URL"] (top bar)
        //   iOS 17+:  textFields["TabBarItemTitle"] (bottom bar tab pill)
        //   iOS 18+ iPad: textFields["Address"]
        //   Fallback: any visible text field.
        let candidateIDs = ["URL", "TabBarItemTitle", "Address"]
        var bar: XCUIElement?
        for id in candidateIDs {
            let f = safari.textFields[id]
            if f.waitForExistence(timeout: 2) { bar = f; break }
        }
        if bar == nil {
            let any = safari.textFields.firstMatch
            if any.waitForExistence(timeout: 3) { bar = any }
        }
        guard let urlBar = bar else {
            XCTFail("Safari address bar not found. Tree:\n\(safari.debugDescription)")
            return
        }
        urlBar.tap()
        // After tap, iOS 26 expands the tab-pill into a separate
        // search field. The originally-tapped pill stays in the tree,
        // so `firstMatch` would return it again. Find the
        // keyboard-focused field instead (identifier contains
        // "isActive=true").
        let activePred = NSPredicate(format:
            "identifier CONTAINS 'isActive=true' OR hasKeyboardFocus == true")
        let active = safari.descendants(matching: .textField).matching(activePred).firstMatch
        if active.waitForExistence(timeout: 3) {
            active.typeText(urlString + "\n")
        } else {
            // Fall back: type into whatever has focus by going through
            // the keyboard directly via app-level typeText.
            safari.typeText(urlString + "\n")
        }
    }

    /// Dismiss Safari's first-launch overlays (iOS 15+ "Continue",
    /// search-suggestions opt-in, and similar one-time prompts). All
    /// taps are best-effort — if the overlay isn't present we just
    /// move on.
    private func dismissSafariFirstLaunch(in app: XCUIApplication) {
        let labels = ["Continue", "Got It", "Got it",
                      "Allow", "Don't Allow", "Not Now",
                      "Maybe Later", "Skip"]
        for label in labels {
            let b = app.buttons[label]
            if b.waitForExistence(timeout: 1) {
                b.tap()
            }
        }
    }

    /// Switch the active keyboard to LimeIME. Fails the test if it
    /// cannot, because every rebuild resets the active keyboard to the
    /// system default and a stroke fixture against the system English
    /// keyboard would silently produce zero signposts.
    private func switchToLimeIME(in app: XCUIApplication, im: String) throws {
        let kb = app.keyboards.firstMatch
        XCTAssertTrue(kb.waitForExistence(timeout: 5),
                      "Keyboard did not appear (im=\(im))")

        // If LimeIME is already active, skip.
        if isLimeKeyboardActive(in: app) { return }

        // The globe / next-keyboard button label varies by iOS version
        // and device class. iPad iOS 26 typically exposes it as a
        // button with one of these identifiers/labels.
        let labelCandidates = [
            "Next keyboard", "Next Keyboard",
            "Emoji", "🌐",
            "Choose Input Method",
        ]
        var globe: XCUIElement?
        for label in labelCandidates {
            let b = kb.buttons[label]
            if b.exists { globe = b; break }
        }
        if globe == nil {
            // Last resort: scan keyboard buttons for a globe-ish glyph.
            let pred = NSPredicate(format:
                "label CONTAINS[c] 'globe' OR label CONTAINS[c] 'next' OR label == '🌐'")
            let b = kb.buttons.matching(pred).firstMatch
            if b.exists { globe = b }
        }
        guard let globeButton = globe else {
            XCTFail("""
                Could not find globe / next-keyboard button.
                Keyboard a11y tree:
                \(kb.debugDescription)
                """)
            return
        }

        // Long-press to open the keyboard picker.
        globeButton.press(forDuration: 0.8)

        // Tap the LimeIME entry. The picker surfaces enabled keyboards
        // as buttons whose label is the keyboard's CFBundleDisplayName.
        // LimeKeyboard's display name is "萊姆輸入法" (set in
        // LimeKeyboard/Info.plist) — not "LimeIME". On iPad iOS 26 the
        // picker may render as menu items (cells) under SpringBoard, so
        // search across element types and across both the app and
        // SpringBoard.
        let limePredicate = NSPredicate(format:
            "label CONTAINS '萊姆' OR label CONTAINS[c] 'lime'")
        let springBoard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let candidates: [XCUIElement] = [
            app.buttons.matching(limePredicate).firstMatch,
            app.cells.matching(limePredicate).firstMatch,
            app.menuItems.matching(limePredicate).firstMatch,
            app.staticTexts.matching(limePredicate).firstMatch,
            springBoard.buttons.matching(limePredicate).firstMatch,
            springBoard.cells.matching(limePredicate).firstMatch,
            springBoard.menuItems.matching(limePredicate).firstMatch,
            springBoard.staticTexts.matching(limePredicate).firstMatch,
        ]
        var limeButton: XCUIElement?
        // Allow up to 3s for the picker to appear, polling each candidate.
        let deadline = Date().addingTimeInterval(3)
        outer: while Date() < deadline {
            for c in candidates where c.exists {
                limeButton = c
                break outer
            }
            usleep(100_000)
        }
        guard let lime = limeButton else {
            XCTFail("""
                LimeIME (萊姆輸入法) not found in keyboard picker.
                Make sure it is enabled in Settings → General →
                Keyboard → Keyboards.

                ───── Safari tree (truncated) ─────
                \(String(app.debugDescription.prefix(4000)))

                ───── SpringBoard tree (truncated) ─────
                \(String(springBoard.debugDescription.prefix(4000)))
                """)
            return
        }
        lime.tap()

        // After tapping the picker, the textarea may have lost focus
        // (the picker is modal). Re-focus it so the new keyboard
        // renders. Wait for it — webview elements can take a moment
        // to repopulate the a11y tree after the picker dismisses.
        let safariApp = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        let textArea = safariApp.webViews.textViews.firstMatch
        XCTAssertTrue(textArea.waitForExistence(timeout: 5),
                      "Textarea vanished after keyboard switch (im=\(im))")
        textArea.tap()

        // Verify the switch took effect. Allow up to 2s for the
        // keyboard to swap.
        let deadline2 = Date().addingTimeInterval(2)
        var active = false
        while Date() < deadline2 {
            if isLimeKeyboardActive(in: app) { active = true; break }
            usleep(100_000)
        }
        if !active {
            let kb = app.keyboards.firstMatch
            // Also dump the whole app tree if no keyboard is present.
            let dump = kb.exists
                ? String(kb.debugDescription.prefix(6000))
                : "No keyboard. App tree:\n" +
                  String(app.debugDescription.prefix(6000))
            XCTFail("""
                LimeIME did not become active after globe-key switch
                (im=\(im)).
                \(dump)
                """)
        }
    }

    /// Heuristic: LimeIME is active if its candidate-bar accessibility
    /// elements are present. Falls back to checking for the keyboard's
    /// distinctive identifier if the candidate bar is empty.
    private func isLimeKeyboardActive(in app: XCUIApplication) -> Bool {
        // The LimeKeyboard candidate bar is built from CandidateBarView;
        // its cells/buttons live under the keyboard input view.
        // Cheapest tell: any button label starting with a CJK char while
        // the keyboard is visible. But on first focus the bar is empty,
        // so check for the keyboard input-view identifier instead.
        let kb = app.keyboards.firstMatch
        guard kb.exists else { return false }
        // Look for buttons unique to LimeIME (e.g. the symbol-page
        // toggle "符" or the IM switcher). Adjust if KeyboardView ever
        // changes the labels.
        let pred = NSPredicate(format:
            "label CONTAINS '符' OR label CONTAINS 'ㄅ' OR label CONTAINS '注音' OR label CONTAINS 'Lime'")
        return kb.buttons.matching(pred).firstMatch.exists
    }
}
