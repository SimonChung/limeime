// PreferencesTabView.swift
// LimeIME-iOS
//
// IM Preferences — all 11 sections with @AppStorage(store: sharedDefaults).
// Spec §8.

import SwiftUI

// MARK: - PreferencesTabView

struct PreferencesTabView: View {

    // MARK: §8.1 Keyboard Appearance
    @AppStorage("keyboard_theme",          store: sharedDefaults) private var keyboardTheme: Int = 0
    @AppStorage("enable_emoji",            store: sharedDefaults) private var enableEmoji: Bool = true
    @AppStorage("enable_emoji_position",   store: sharedDefaults) private var emojiPosition: Int = 3
    @AppStorage("keyboard_size",           store: sharedDefaults) private var keyboardSize: String = "1.1"
    @AppStorage("show_arrow_key",          store: sharedDefaults) private var showArrowKey: Int = 0
    @AppStorage("split_keyboard_mode",     store: sharedDefaults) private var splitKeyboardMode: Int = 0

    // MARK: §8.2 Keyboard Feedback
    @AppStorage("vibrate_on_keypress",     store: sharedDefaults) private var vibrateOnKeypress: Bool = true
    @AppStorage("vibrate_level",           store: sharedDefaults) private var vibrateLevel: Int = 40
    @AppStorage("sound_on_keypress",       store: sharedDefaults) private var soundOnKeypress: Bool = false

    // MARK: §8.3 Font & Display
    @AppStorage("font_size",              store: sharedDefaults) private var fontSize: String = "1.1"
    @AppStorage("number_row_in_english",  store: sharedDefaults) private var numberRowInEnglish: Bool = true

    // MARK: §8.4 IM Behaviour
    @AppStorage("smart_chinese_input",    store: sharedDefaults) private var smartChineseInput: Bool = false
    @AppStorage("auto_chinese_symbol",    store: sharedDefaults) private var autoChineseSymbol: Bool = false
    @AppStorage("selkey_option",          store: sharedDefaults) private var selkeyOption: Int = 0
    @AppStorage("auto_commit",            store: sharedDefaults) private var autoCommit: Int = 0
    @AppStorage("candidate_switch",       store: sharedDefaults) private var candidateSwitch: Bool = true

    // MARK: §8.5 Phonetic Keyboard
    @AppStorage("phonetic_keyboard_type", store: sharedDefaults) private var phoneticKeyboardType: String = "standard"

    // MARK: §8.6 Han Conversion
    @AppStorage("han_convert_option",     store: sharedDefaults) private var hanConvertOption: Int = 0
    @AppStorage("han_convert_notify",     store: sharedDefaults) private var hanConvertNotify: Bool = true

    // MARK: §8.7 Related Phrases & Learning
    @AppStorage("similiar_enable",        store: sharedDefaults) private var similiarEnable: Bool = true
    @AppStorage("similiar_list",          store: sharedDefaults) private var similiarList: Int = 20
    @AppStorage("candidate_suggestion",   store: sharedDefaults) private var candidateSuggestion: Bool = true
    @AppStorage("learn_phrase",           store: sharedDefaults) private var learnPhrase: Bool = true
    @AppStorage("learning_switch",        store: sharedDefaults) private var learningSwitch: Bool = true

    // MARK: §8.8 English Dictionary
    @AppStorage("english_dictionary_enable",             store: sharedDefaults) private var englishDictEnable: Bool = true

    // MARK: §8.9 Advanced
    @AppStorage("reverse_lookup_notify",    store: sharedDefaults) private var reverseLookupNotify: Bool = true
    @AppStorage("persistent_language_mode", store: sharedDefaults) private var persistentLanguageMode: Bool = false

    // MARK: Options

    // iOS-only value 6 = 系統設定 (follows UITraitCollection); must not be synced to Android pref store.
    private let themeOptions    = [0, 1, 2, 3, 4, 5, 6]
    private let themeLabels     = ["淺色", "深色", "粉紅", "科技藍", "時尚紫", "放鬆綠", "系統設定"]
    private let sizeOptions     = ["1.2", "1.1", "1", "0.9", "0.8"]
    private let sizeLabels      = ["特大", "大", "一般", "小", "特小"]
    private let arrowOptions    = [0, 1, 2]
    private let arrowLabels     = ["無", "鍵盤上方", "鍵盤下方"]
    private let splitOptions    = [0, 1, 2]
    private let splitLabels     = ["關閉", "開啟", "僅橫向"]
    private let vibLevelOptions = [10, 20, 40, 60, 80]
    private let vibLevelLabels  = ["特弱", "弱", "中", "強", "特強"]
    private let selkeyOptions   = [0, 1, 2]
    private let selkeyLabels    = ["混打英文優先", "第一中文優先", "第二中文優先"]
    private let autoCommitOpts  = [0, 4, 5, 6, 7, 8, 9, 10]
    private let autoCommitLabels = ["無", "4碼", "5碼", "6碼", "7碼", "8碼", "9碼", "10碼"]
    private let phoneticOptions = ["standard", "et_41", "eten26", "eten26_symbol", "hsu", "hsu_symbol"]
    private let phoneticLabels  = ["標準", "倚天 41 鍵", "倚天 26 鍵 (英文)", "倚天 26 鍵 (符號)", "許氏 (英文)", "許氏 (符號)"]
    private let hanOptions      = [0, 1, 2]
    private let hanLabels       = ["不轉換", "繁→簡", "簡→繁"]
    private let similiarOpts    = [0, 10, 20, 30, 40, 50]

    var body: some View {
        NavigationView {
            Form {
                // MARK: §8.1
                Section(header: Text("鍵盤外觀")) {
                    Picker("鍵盤樣式", selection: $keyboardTheme) {
                        ForEach(0..<themeOptions.count, id: \.self) { i in
                            Text(themeLabels[i]).tag(themeOptions[i])
                        }
                    }
                    Toggle("顯示 Emoji", isOn: $enableEmoji)
                    Picker("Emoji 顯示位置", selection: $emojiPosition) {
                        ForEach(2...10, id: \.self) { pos in
                            Text("第 \(pos) 個候選後").tag(pos)
                        }
                    }
                    .disabled(!enableEmoji)
                    Picker("鍵盤大小", selection: $keyboardSize) {
                        ForEach(0..<sizeOptions.count, id: \.self) { i in
                            Text(sizeLabels[i]).tag(sizeOptions[i])
                        }
                    }
                    Picker("顯示方向鍵", selection: $showArrowKey) {
                        ForEach(0..<arrowOptions.count, id: \.self) { i in
                            Text(arrowLabels[i]).tag(arrowOptions[i])
                        }
                    }
                    // iPad-only split keyboard
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Picker("分離鍵盤", selection: $splitKeyboardMode) {
                            ForEach(0..<splitOptions.count, id: \.self) { i in
                                Text(splitLabels[i]).tag(splitOptions[i])
                            }
                        }
                    }
                }

                // MARK: §8.2
                Section(header: Text("鍵盤回饋")) {
                    Toggle("打字震動", isOn: $vibrateOnKeypress)
                    Picker("震動強度", selection: $vibrateLevel) {
                        ForEach(0..<vibLevelOptions.count, id: \.self) { i in
                            Text(vibLevelLabels[i]).tag(vibLevelOptions[i])
                        }
                    }
                    .disabled(!vibrateOnKeypress)
                    Toggle("打字音效", isOn: $soundOnKeypress)
                }

                // MARK: §8.3
                Section(header: Text("字型與顯示")) {
                    Picker("候選字字型大小", selection: $fontSize) {
                        ForEach(0..<sizeOptions.count, id: \.self) { i in
                            Text(sizeLabels[i]).tag(sizeOptions[i])
                        }
                    }
                    Toggle("數字列英文鍵盤", isOn: $numberRowInEnglish)
                }

                // MARK: §8.4
                Section(header: Text("輸入法行為")) {
                    Toggle("智慧組詞", isOn: $smartChineseInput)
                    Toggle("自動中文標點", isOn: $autoChineseSymbol)
                    Picker("選字鍵預選順序", selection: $selkeyOption) {
                        ForEach(0..<selkeyOptions.count, id: \.self) { i in
                            Text(selkeyLabels[i]).tag(selkeyOptions[i])
                        }
                    }
                    Picker("電話鍵盤自動上屏", selection: $autoCommit) {
                        ForEach(0..<autoCommitOpts.count, id: \.self) { i in
                            Text(autoCommitLabels[i]).tag(autoCommitOpts[i])
                        }
                    }
                    Toggle("滑動選取候選字", isOn: $candidateSwitch)
                }

                // MARK: §8.5
                Section(header: Text("注音鍵盤")) {
                    Picker("鍵盤類型", selection: $phoneticKeyboardType) {
                        ForEach(0..<phoneticOptions.count, id: \.self) { i in
                            Text(phoneticLabels[i]).tag(phoneticOptions[i])
                        }
                    }
                    .onChange(of: phoneticKeyboardType) { newType in
                        updatePhoneticKeyboard(type: newType)
                    }
                }

                // MARK: §8.6
                Section(header: Text("漢字轉換")) {
                    Picker("簡繁轉換", selection: $hanConvertOption) {
                        ForEach(0..<hanOptions.count, id: \.self) { i in
                            Text(hanLabels[i]).tag(hanOptions[i])
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("轉換提示", isOn: $hanConvertNotify)
                }

                // MARK: §8.7
                Section(header: Text("關聯字與學習")) {
                    Toggle("啟用關聯字典", isOn: $similiarEnable)
                    Picker("建議字顯示數量", selection: $similiarList) {
                        ForEach(similiarOpts, id: \.self) { v in
                            Text(v == 0 ? "關閉" : "\(v)").tag(v)
                        }
                    }
                    .disabled(!similiarEnable)
                    Toggle("自動學習關聯字", isOn: $candidateSuggestion)
                    Toggle("自動學習新詞", isOn: $learnPhrase)
                    Toggle("依選取次數排序", isOn: $learningSwitch)
                }

                // MARK: §8.8
                Section(header: Text("英文字典")) {
                    Toggle("啟用英文建議字", isOn: $englishDictEnable)
                }

                // MARK: §8.9
                Section(header: Text("進階")) {
                    Toggle("字根反查提示", isOn: $reverseLookupNotify)
                    Toggle("記憶中英模式", isOn: $persistentLanguageMode)
                }

                // MARK: §8.11 sub-screen
                Section {
                    NavigationLink(destination: ReverseLookupSettingsView()) {
                        Label("字根反查設定", systemImage: "magnifyingglass")
                    }
                }

                // MARK: About
                Section(header: Text("關於")) {
                    LabeledContent("版本", value: appVersion())
                    LabeledContent("授權", value: "GPL-3.0")
                    Link("原始碼 (GitHub)",
                         destination: URL(string: "https://github.com/lime-ime/limeime")!)
                }
            }
            .navigationTitle("偏好設定")
        }
    }

    private func updatePhoneticKeyboard(type: String) {
        Task.detached(priority: .background) {
            let server = DBServer.shared
            if let kbList = server.getKeyboardConfigList(),
               let kb = kbList.first(where: { $0.code == type }) {
                server.setImConfigKeyboard("phonetic", kb)
            }
        }
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
