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
    @AppStorage("smart_chinese_input",    store: sharedDefaults) private var smartChineseInput: Bool = true
    @AppStorage("auto_chinese_symbol",    store: sharedDefaults) private var autoChineseSymbol: Bool = true
    @AppStorage("candidate_switch",       store: sharedDefaults) private var candidateSwitch: Bool = true

    // §8.5 "鍵盤類型" (phonetic_keyboard_type) is IM-specific — now rendered in
    // IMDetailView for the phonetic IM only.

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
    private let hanOptions      = [0, 1, 2]
    private let hanLabels       = ["不轉換", "繁→簡", "簡→繁"]
    private let similiarOpts    = [0, 10, 20, 30, 40, 50]

    @ViewBuilder
    private func prefRow(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

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
                    Toggle(isOn: $enableEmoji) { prefRow("顯示 Emoji", "依字根或中文組字顯示圖示，由於字型支援的差異所以部份圖示可能無法正確顯示") }
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
                    Toggle(isOn: $numberRowInEnglish) { prefRow("數字列英文鍵盤", "在英文鍵盤顯示數字列(5列鍵盤)") }
                }

                // MARK: §8.4
                Section(header: Text("輸入法行為")) {
                    Toggle(isOn: $smartChineseInput) { prefRow("智慧組詞", "部份輸入法可能會影響中英混打功能") }
                    Toggle(isOn: $autoChineseSymbol) { prefRow("自動中文標點", "無候選字詞時顯示中文標點選項") }
                    Toggle(isOn: $candidateSwitch) { prefRow("滑動選取候選字", "滑動選取輸入法建議文字") }
                }

                // §8.5 moved — 鍵盤類型 now lives in IMDetailView for the phonetic IM.

                // MARK: §8.6
                Section(header: Text("漢字轉換")) {
                    Picker("簡繁轉換", selection: $hanConvertOption) {
                        ForEach(0..<hanOptions.count, id: \.self) { i in
                            Text(hanLabels[i]).tag(hanOptions[i])
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $hanConvertNotify) { prefRow("轉換提示", "輸入間隔時間超過60s時提示轉換的設定") }
                }

                // MARK: §8.7
                Section(header: Text("關聯字與學習")) {
                    Toggle(isOn: $similiarEnable) { prefRow("啟用關聯字典", "啟用關聯字典功能") }
                    Picker("建議字顯示數量", selection: $similiarList) {
                        ForEach(similiarOpts, id: \.self) { v in
                            Text(v == 0 ? "關閉" : "\(v)").tag(v)
                        }
                    }
                    .disabled(!similiarEnable)
                    Toggle(isOn: $candidateSuggestion) { prefRow("自動學習關聯字", "依輸入文字自動建立關聯字") }
                    Toggle(isOn: $learnPhrase) { prefRow("自動學習新詞", "從常用關聯字學習新詞") }
                    Toggle(isOn: $learningSwitch) { prefRow("啟動選取排序", "依選取次數排序選字清單") }
                }

                // MARK: §8.8
                Section(header: Text("英文字典")) {
                    Toggle(isOn: $englishDictEnable) { prefRow("啟用英文建議字", "當使用英文輸入模式時，顯示英文建議字") }
                }

                // MARK: §8.9
                Section(header: Text("進階")) {
                    Toggle("字根反查提示", isOn: $reverseLookupNotify)
                    Toggle(isOn: $persistentLanguageMode) { prefRow("記憶中英模式", "下次切換前保持中英模式") }
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
            .navigationTitle("喜好設定")
        }
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
