// LIMEPreferenceManagerTest.swift
// LimeIMETests
//
// Round-trip tests for every preference key in spec §9.
// Uses an isolated in-memory UserDefaults suite so no real App Group is needed.

import XCTest
@testable import LimeIME

// MARK: - LIMEPreferenceManagerTest

final class LIMEPreferenceManagerTest: XCTestCase {

    private var suiteName: String!
    private var testDefaults: UserDefaults!
    private var prefs: LIMEPreferenceManager!

    override func setUp() {
        super.setUp()
        suiteName = "test.lime.prefs.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        prefs = LIMEPreferenceManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Default values

    func testDefaultKeyboardTheme() {
        XCTAssertEqual(prefs.keyboardTheme, 0)
    }

    func testDefaultEnableEmoji() {
        XCTAssertTrue(prefs.enableEmoji)
    }

    func testDefaultEnableEmojiPosition() {
        XCTAssertEqual(prefs.enableEmojiPosition, 3)
    }

    func testDefaultKeyboardSize() {
        XCTAssertEqual(prefs.keyboardSize, "1.1")
    }

    func testDefaultFontSize() {
        XCTAssertEqual(prefs.fontSize, "1.1")
    }

    func testDefaultCandidateFontSize() {
        XCTAssertEqual(prefs.candidateFontSize, 18)
    }

    func testDefaultShowArrowKey() {
        XCTAssertEqual(prefs.showArrowKey, 0)
    }

    func testDefaultSplitKeyboardMode() {
        XCTAssertEqual(prefs.splitKeyboardMode, 0)
    }

    func testDefaultVibrateOnKeypress() {
        XCTAssertTrue(prefs.vibrateOnKeypress)
    }

    func testDefaultVibrateLevel() {
        XCTAssertEqual(prefs.vibrateLevel, 40)
    }

    func testDefaultSoundOnKeypress() {
        XCTAssertFalse(prefs.soundOnKeypress)
    }

    func testDefaultNumberRowInEnglish() {
        XCTAssertTrue(prefs.numberRowInEnglish)
    }

    func testDefaultSmartChineseInput() {
        XCTAssertFalse(prefs.smartChineseInput)
    }

    func testDefaultAutoChineseSymbol() {
        XCTAssertFalse(prefs.autoChineseSymbol)
    }

    func testDefaultAutoCommit() {
        XCTAssertEqual(prefs.autoCommit, 0)
    }

    func testDefaultCandidateSwitch() {
        XCTAssertTrue(prefs.candidateSwitch)
    }

    func testDefaultPhoneticKeyboardType() {
        XCTAssertEqual(prefs.phoneticKeyboardType, "standard")
    }

    func testDefaultHanConvertOption() {
        XCTAssertEqual(prefs.hanConvertOption, 0)
    }

    func testDefaultHanConvertNotify() {
        XCTAssertTrue(prefs.hanConvertNotify)
    }

    func testDefaultReverseLookupNotify() {
        XCTAssertTrue(prefs.reverseLookupNotify)
    }

    func testDefaultSimiliarEnable() {
        XCTAssertTrue(prefs.similiarEnable)
    }

    func testDefaultSimiliarList() {
        XCTAssertEqual(prefs.similiarList, 20)
    }

    func testDefaultCandidateSuggestion() {
        XCTAssertTrue(prefs.candidateSuggestion)
    }

    func testDefaultLearnPhrase() {
        XCTAssertTrue(prefs.learnPhrase)
    }

    func testDefaultLearningSwitch() {
        XCTAssertTrue(prefs.learningSwitch)
    }

    func testDefaultEnglishDictionaryEnable() {
        XCTAssertTrue(prefs.englishDictionaryEnable)
    }

    func testDefaultAcceptNumberIndex() {
        XCTAssertFalse(prefs.acceptNumberIndex)
    }

    func testDefaultAcceptSymbolIndex() {
        XCTAssertFalse(prefs.acceptSymbolIndex)
    }

    func testDefaultPersistentLanguageMode() {
        XCTAssertFalse(prefs.persistentLanguageMode)
    }

    // Reverse lookup defaults
    func testDefaultReverseLookupKeys() {
        XCTAssertEqual(prefs.customImReverselookup, "none")
        XCTAssertEqual(prefs.cjImReverselookup,     "none")
        XCTAssertEqual(prefs.scjImReverselookup,    "none")
        XCTAssertEqual(prefs.cj5ImReverselookup,    "none")
        XCTAssertEqual(prefs.ecjImReverselookup,    "none")
        XCTAssertEqual(prefs.dayiImReverselookup,   "none")
        XCTAssertEqual(prefs.bpmfImReverselookup,   "none")
        XCTAssertEqual(prefs.ezImReverselookup,     "none")
        XCTAssertEqual(prefs.arrayImReverselookup,  "none")
        XCTAssertEqual(prefs.array10ImReverselookup,"none")
        XCTAssertEqual(prefs.wbImReverselookup,     "none")
        XCTAssertEqual(prefs.hsImReverselookup,     "none")
        XCTAssertEqual(prefs.pinyinImReverselookup, "none")
    }

    // MARK: - Round-trip setters

    func testKeyboardThemeSystemValue() {
        // Default should be 0 (淺色)
        XCTAssertEqual(prefs.keyboardTheme, 0)
        // Value 6 (系統設定, iOS-only) must round-trip correctly
        prefs.keyboardTheme = 6
        XCTAssertEqual(prefs.keyboardTheme, 6)
    }

    func testRoundTripKeyboardTheme() {
        prefs.keyboardTheme = 3
        XCTAssertEqual(prefs.keyboardTheme, 3)
    }

    func testRoundTripEnableEmoji() {
        prefs.enableEmoji = false
        XCTAssertFalse(prefs.enableEmoji)
    }

    func testRoundTripKeyboardSize() {
        prefs.keyboardSize = "0.9"
        XCTAssertEqual(prefs.keyboardSize, "0.9")
    }

    func testRoundTripFontSize() {
        prefs.fontSize = "1.2"
        XCTAssertEqual(prefs.fontSize, "1.2")
    }

    func testRoundTripCandidateFontSize() {
        prefs.candidateFontSize = 22.0
        XCTAssertEqual(prefs.candidateFontSize, 22.0)
    }

    func testRoundTripVibrateLevel() {
        prefs.vibrateLevel = 60
        XCTAssertEqual(prefs.vibrateLevel, 60)
    }

    func testRoundTripPhoneticKeyboardType() {
        prefs.phoneticKeyboardType = "hsu"
        XCTAssertEqual(prefs.phoneticKeyboardType, "hsu")
    }

    func testRoundTripHanConvertOption() {
        prefs.hanConvertOption = 2
        XCTAssertEqual(prefs.hanConvertOption, 2)
    }

    func testRoundTripSimiliarList() {
        prefs.similiarList = 30
        XCTAssertEqual(prefs.similiarList, 30)
    }

    func testRoundTripReverseLookupCustom() {
        prefs.customImReverselookup = "cj"
        XCTAssertEqual(prefs.customImReverselookup, "cj")
    }

    func testRoundTripReverseLookupBpmf() {
        prefs.bpmfImReverselookup = "phonetic"
        XCTAssertEqual(prefs.bpmfImReverselookup, "phonetic")
    }

    func testRoundTripKeyboardList() {
        prefs.keyboardList = "cj"
        XCTAssertEqual(prefs.keyboardList, "cj")
    }

    func testRoundTripKeyboardState() {
        prefs.keyboardState = "0;1;2"
        XCTAssertEqual(prefs.keyboardState, "0;1;2")
    }

    // MARK: - Suite isolation

    func testSuiteIsolation() {
        // Two managers with different suites should not share values
        let suite2 = "test.lime.prefs.b.\(UUID().uuidString)"
        let defaults2 = UserDefaults(suiteName: suite2)!
        let prefs2 = LIMEPreferenceManager(defaults: defaults2)

        prefs.keyboardTheme = 5
        XCTAssertEqual(prefs.keyboardTheme, 5)
        XCTAssertEqual(prefs2.keyboardTheme, 0) // default, not 5

        defaults2.removePersistentDomain(forName: suite2)
    }

    // MARK: - syncIMActivatedState

    func testSyncIMActivatedStateEmpty() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        // LIMEPreferenceManager is in Shared, compiled into LimeIMETests — use LimeDB directly
        let db = try LimeDB(path: tempURL.path)
        prefs.syncIMActivatedState(db: db)
        let state = prefs.keyboardState
        XCTAssertNotNil(state)
    }

    func testSyncIMActivatedStateWithIMs() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let db = try LimeDB(path: tempURL.path)
        _ = db.openDBConnection(false)
        prefs.syncIMActivatedState(db: db)
        let state = prefs.keyboardState
        XCTAssertNotNil(state)
    }
}
