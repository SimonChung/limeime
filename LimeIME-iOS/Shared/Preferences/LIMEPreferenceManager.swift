// LIMEPreferenceManager.swift
// LimeIME-iOS
//
// Model layer: typed accessors for all shared UserDefaults preference keys.
// Port of Android LIMEPreferenceManager.java.
// All values stored in the shared App Group suite so the keyboard extension
// can read them without IPC.

import Foundation

// MARK: - LIMEPreferenceManager

final class LIMEPreferenceManager {

    // MARK: - Singleton

    static let shared = LIMEPreferenceManager()

    // MARK: - Constants

    static let suiteName = "group.net.toload.limeime"

    // MARK: - Storage

    private let defaults: UserDefaults

    // MARK: - Init

    /// Designated initialiser — uses the shared App Group suite.
    init() {
        defaults = UserDefaults(suiteName: LIMEPreferenceManager.suiteName)
            ?? UserDefaults.standard
    }

    /// Test helper: inject any UserDefaults instance.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Generic helpers

    private func intValue(_ key: String, default defaultValue: Int) -> Int {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.integer(forKey: key)
    }

    private func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func stringValue(_ key: String, default defaultValue: String) -> String {
        return defaults.string(forKey: key) ?? defaultValue
    }

    private func doubleValue(_ key: String, default defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.double(forKey: key)
    }

    // MARK: - §8.1 Keyboard Appearance

    /// Keyboard colour palette index.
    /// Values 0–5 are explicit palettes (淺色/深色/粉紅/科技藍/時尚紫/放鬆綠).
    /// Value 6 is iOS-only "系統設定": callers in the keyboard extension must map it to 0 (light)
    /// or 1 (dark) based on `UITraitCollection.current.userInterfaceStyle`.
    /// Do NOT sync value 6 back to the Android preference store.
    var keyboardTheme: Int {
        get { intValue("keyboard_theme", default: 0) }
        set { defaults.set(newValue, forKey: "keyboard_theme") }
    }

    var enableEmoji: Bool {
        get { boolValue("enable_emoji", default: true) }
        set { defaults.set(newValue, forKey: "enable_emoji") }
    }

    var enableEmojiPosition: Int {
        get { intValue("enable_emoji_position", default: 3) }
        set { defaults.set(newValue, forKey: "enable_emoji_position") }
    }

    var keyboardSize: String {
        get { stringValue("keyboard_size", default: "1.1") }
        set { defaults.set(newValue, forKey: "keyboard_size") }
    }

    var showArrowKey: Int {
        get { intValue("show_arrow_key", default: 0) }
        set { defaults.set(newValue, forKey: "show_arrow_key") }
    }

    var splitKeyboardMode: Int {
        get { intValue("split_keyboard_mode", default: 0) }
        set { defaults.set(newValue, forKey: "split_keyboard_mode") }
    }

    // MARK: - §8.2 Keyboard Feedback

    var vibrateOnKeypress: Bool {
        get { boolValue("vibrate_on_keypress", default: true) }
        set { defaults.set(newValue, forKey: "vibrate_on_keypress") }
    }

    var vibrateLevel: Int {
        get { intValue("vibrate_level", default: 40) }
        set { defaults.set(newValue, forKey: "vibrate_level") }
    }

    var soundOnKeypress: Bool {
        get { boolValue("sound_on_keypress", default: false) }
        set { defaults.set(newValue, forKey: "sound_on_keypress") }
    }

    // MARK: - §8.3 Font & Display

    var fontSize: String {
        get { stringValue("font_size", default: "1.1") }
        set { defaults.set(newValue, forKey: "font_size") }
    }

    /// Raw candidate font size in points (14–28). Separate from font_size scale string.
    var candidateFontSize: Double {
        get { doubleValue("candidateFontSize", default: 18) }
        set { defaults.set(newValue, forKey: "candidateFontSize") }
    }

    var numberRowInEnglish: Bool {
        get { boolValue("number_row_in_english", default: true) }
        set { defaults.set(newValue, forKey: "number_row_in_english") }
    }

    // MARK: - §8.4 IM Behaviour

    var smartChineseInput: Bool {
        get { boolValue("smart_chinese_input", default: false) }
        set { defaults.set(newValue, forKey: "smart_chinese_input") }
    }

    var autoChineseSymbol: Bool {
        get { boolValue("auto_chinese_symbol", default: false) }
        set { defaults.set(newValue, forKey: "auto_chinese_symbol") }
    }

    var autoCommit: Int {
        get { intValue("auto_commit", default: 0) }
        set { defaults.set(newValue, forKey: "auto_commit") }
    }

    var candidateSwitch: Bool {
        get { boolValue("candidate_switch", default: true) }
        set { defaults.set(newValue, forKey: "candidate_switch") }
    }

    // MARK: - §8.5 Phonetic Keyboard

    var phoneticKeyboardType: String {
        get { stringValue("phonetic_keyboard_type", default: "standard") }
        set { defaults.set(newValue, forKey: "phonetic_keyboard_type") }
    }

    // MARK: - §8.6 Han Conversion

    var hanConvertOption: Int {
        get { intValue("han_convert_option", default: 0) }
        set { defaults.set(newValue, forKey: "han_convert_option") }
    }

    var hanConvertNotify: Bool {
        get { boolValue("han_convert_notify", default: true) }
        set { defaults.set(newValue, forKey: "han_convert_notify") }
    }

    var reverseLookupNotify: Bool {
        get { boolValue("reverse_lookup_notify", default: true) }
        set { defaults.set(newValue, forKey: "reverse_lookup_notify") }
    }

    // MARK: - §8.7 Related Phrases & Learning

    var similiarEnable: Bool {
        get { boolValue("similiar_enable", default: true) }
        set { defaults.set(newValue, forKey: "similiar_enable") }
    }

    var similiarList: Int {
        get { intValue("similiar_list", default: 20) }
        set { defaults.set(newValue, forKey: "similiar_list") }
    }

    var candidateSuggestion: Bool {
        get { boolValue("candidate_suggestion", default: true) }
        set { defaults.set(newValue, forKey: "candidate_suggestion") }
    }

    var learnPhrase: Bool {
        get { boolValue("learn_phrase", default: true) }
        set { defaults.set(newValue, forKey: "learn_phrase") }
    }

    var learningSwitch: Bool {
        get { boolValue("learning_switch", default: true) }
        set { defaults.set(newValue, forKey: "learning_switch") }
    }

    // MARK: - §8.8 English Dictionary

    var englishDictionaryEnable: Bool {
        get { boolValue("english_dictionary_enable", default: true) }
        set { defaults.set(newValue, forKey: "english_dictionary_enable") }
    }

    // MARK: - §8.9 Advanced

    var acceptNumberIndex: Bool {
        get { boolValue("accept_number_index", default: false) }
        set { defaults.set(newValue, forKey: "accept_number_index") }
    }

    var acceptSymbolIndex: Bool {
        get { boolValue("accept_symbol_index", default: false) }
        set { defaults.set(newValue, forKey: "accept_symbol_index") }
    }

    var persistentLanguageMode: Bool {
        get { boolValue("persistent_language_mode", default: false) }
        set { defaults.set(newValue, forKey: "persistent_language_mode") }
    }

    /// Stored Chinese/English state: "yes" = English-only, "no" = Chinese (spec §15).
    /// Written by setLanguageMode when persistentLanguageMode is enabled.
    var languageMode: String {
        get { stringValue("language_mode", default: "no") }
        set { defaults.set(newValue, forKey: "language_mode") }
    }

    var displayNumberKeypads: Bool {
        get { boolValue("display_number_keypads", default: false) }
        set { defaults.set(newValue, forKey: "display_number_keypads") }
    }

    var autoCap: Bool {
        get { boolValue("auto_cap", default: true) }
        set { defaults.set(newValue, forKey: "auto_cap") }
    }

    // MARK: - §8.11 Reverse Lookup

    var customImReverselookup: String {
        get { stringValue("custom_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "custom_im_reverselookup") }
    }

    var cjImReverselookup: String {
        get { stringValue("cj_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "cj_im_reverselookup") }
    }

    var scjImReverselookup: String {
        get { stringValue("scj_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "scj_im_reverselookup") }
    }

    var cj5ImReverselookup: String {
        get { stringValue("cj5_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "cj5_im_reverselookup") }
    }

    var ecjImReverselookup: String {
        get { stringValue("ecj_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "ecj_im_reverselookup") }
    }

    var dayiImReverselookup: String {
        get { stringValue("dayi_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "dayi_im_reverselookup") }
    }

    var bpmfImReverselookup: String {
        get { stringValue("bpmf_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "bpmf_im_reverselookup") }
    }

    var ezImReverselookup: String {
        get { stringValue("ez_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "ez_im_reverselookup") }
    }

    var arrayImReverselookup: String {
        get { stringValue("array_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "array_im_reverselookup") }
    }

    var array10ImReverselookup: String {
        get { stringValue("array10_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "array10_im_reverselookup") }
    }

    var wbImReverselookup: String {
        get { stringValue("wb_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "wb_im_reverselookup") }
    }

    var hsImReverselookup: String {
        get { stringValue("hs_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "hs_im_reverselookup") }
    }

    var pinyinImReverselookup: String {
        get { stringValue("pinyin_im_reverselookup", default: "none") }
        set { defaults.set(newValue, forKey: "pinyin_im_reverselookup") }
    }

    // MARK: - Navigation state

    var keyboardList: String {
        get { stringValue("keyboard_list", default: "phonetic") }
        set { defaults.set(newValue, forKey: "keyboard_list") }
    }

    var keyboardState: String {
        get { stringValue("keyboard_state", default: "") }
        set { defaults.set(newValue, forKey: "keyboard_state") }
    }

    // MARK: - §10.4 syncIMActivatedState

    /// Rebuilds the keyboard_state semicolon-delimited string from im.enabled rows.
    /// Mirrors Android's LIMEPreferenceManager.syncIMActivatedState().
    /// - Parameter db: An open LimeDB instance.
    func syncIMActivatedState(db: LimeDB) {
        guard let configs = try? db.getAllImConfigs() else { return }
        let enabledIndices = configs.enumerated()
            .filter { $0.element.enabled }
            .map { "\($0.offset)" }
        let state = enabledIndices.joined(separator: ";")
        keyboardState = state
    }

    /// DBServer-based overload — use this in Controllers to avoid direct LimeDB access.
    func syncIMActivatedState(dbServer: DBServer) {
        guard let configs = try? dbServer.getAllImConfigs() else { return }
        let enabledIndices = configs.enumerated()
            .filter { $0.element.enabled }
            .map { "\($0.offset)" }
        keyboardState = enabledIndices.joined(separator: ";")
    }
}
