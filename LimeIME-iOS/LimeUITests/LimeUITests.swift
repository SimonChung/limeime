//
//  LimeUITests.swift
//  LimeUITests
//
//  Created by JEREMY WU on 2026/5/2.
//

import XCTest

final class LimeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testIPadKeyboardAndGlobeLongPressVisuals() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10),
                      "Safari did not become foreground")
        dismissSafariFirstLaunch(in: safari)
        try focusSafariAddressField(in: safari)
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "ipad_longpress_00_keyboard")

        // iPad LIME bottom row: keyboard/options key is the far-right bottom key.
        safari.coordinate(withNormalizedOffset: CGVector(dx: 0.965, dy: 0.965))
            .press(forDuration: 0.9)
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "ipad_longpress_01_keyboard_key_menu")

        safari.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40)).tap()
        Thread.sleep(forTimeInterval: 0.5)

        try focusSafariAddressField(in: safari)
        Thread.sleep(forTimeInterval: 0.5)

        // iPad LIME bottom row: globe key is the far-left bottom key.
        let globeCapture = captureScreenshotDuringHold(named: "ipad_longpress_02_globe_picker")
        safari.coordinate(withNormalizedOffset: CGVector(dx: 0.035, dy: 0.965))
            .press(forDuration: 2.0)
        wait(for: [globeCapture], timeout: 2.0)
    }

    private func captureScreenshotDuringHold(named name: String) -> XCTestExpectation {
        let exp = expectation(description: name)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else {
                exp.fulfill()
                return
            }
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            self.add(attachment)
            exp.fulfill()
        }
        return exp
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func focusSafariAddressField(in app: XCUIApplication) throws {
        let candidateIDs = ["URL", "TabBarItemTitle", "Address"]
        for id in candidateIDs {
            let predicate = NSPredicate(format: "identifier == %@ OR label == %@", id, id)
            let field = app.textFields.matching(predicate).firstMatch
            if field.waitForExistence(timeout: 2) {
                field.tap()
                return
            }
        }

        let anyField = app.textFields.firstMatch
        if anyField.waitForExistence(timeout: 3) {
            anyField.tap()
            return
        }

        XCTFail("Safari address field not found. Tree:\n\(String(app.debugDescription.prefix(4000)))")
    }

    private func dismissSafariFirstLaunch(in app: XCUIApplication) {
        let labels = ["Continue", "Got It", "Got it", "Allow", "Don't Allow", "Not Now", "Maybe Later", "Skip"]
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 1) {
                button.tap()
            }
        }
    }

    private func saveScreenshot(named name: String) throws {
        let outputDir = ProcessInfo.processInfo.environment["LIME_VISUAL_VERIFY_OUTPUT_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
