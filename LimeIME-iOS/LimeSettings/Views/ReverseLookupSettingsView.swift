// ReverseLookupSettingsView.swift
// LimeIME-iOS
//
// Per-IM reverse lookup source pickers.
// Spec §8.11.

import SwiftUI

// MARK: - ReverseLookupSettingsView

struct ReverseLookupSettingsView: View {

    // All 13 reverse-lookup preference keys
    @AppStorage("custom_im_reverselookup",  store: sharedDefaults) private var custom: String  = "none"
    @AppStorage("cj_im_reverselookup",      store: sharedDefaults) private var cj: String      = "none"
    @AppStorage("scj_im_reverselookup",     store: sharedDefaults) private var scj: String     = "none"
    @AppStorage("cj5_im_reverselookup",     store: sharedDefaults) private var cj5: String     = "none"
    @AppStorage("ecj_im_reverselookup",     store: sharedDefaults) private var ecj: String     = "none"
    @AppStorage("dayi_im_reverselookup",    store: sharedDefaults) private var dayi: String    = "none"
    @AppStorage("bpmf_im_reverselookup",    store: sharedDefaults) private var bpmf: String    = "none"
    @AppStorage("ez_im_reverselookup",      store: sharedDefaults) private var ez: String      = "none"
    @AppStorage("array_im_reverselookup",   store: sharedDefaults) private var array: String   = "none"
    @AppStorage("array10_im_reverselookup", store: sharedDefaults) private var array10: String = "none"
    @AppStorage("wb_im_reverselookup",      store: sharedDefaults) private var wb: String      = "none"
    @AppStorage("hs_im_reverselookup",      store: sharedDefaults) private var hs: String      = "none"
    @AppStorage("pinyin_im_reverselookup",  store: sharedDefaults) private var pinyin: String  = "none"

    // Available lookup source options (spec §8.11)
    private let lookupValues = ["none", "custom", "cj", "scj", "cj5", "ecj",
                                 "dayi", "phonetic", "ez", "array", "array10",
                                 "wb", "hs", "pinyin"]
    private let lookupLabels = ["無", "自建", "倉頡", "快倉", "倉頡五代", "速成",
                                 "大易", "注音", "輕鬆", "行列", "行列 10",
                                 "筆順五碼", "華象直覺", "拼音"]

    var body: some View {
        Form {
            Section(header: Text("說明")) {
                Text("輸入字根無候選字時，以其他輸入法字根標注說明。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("各輸入法反查來源")) {
                lookupPicker("自建",     selection: $custom)
                lookupPicker("倉頡",     selection: $cj)
                lookupPicker("快倉",     selection: $scj)
                lookupPicker("倉頡五代", selection: $cj5)
                lookupPicker("速成",     selection: $ecj)
                lookupPicker("大易",     selection: $dayi)
                lookupPicker("注音",     selection: $bpmf)
                lookupPicker("輕鬆",     selection: $ez)
                lookupPicker("行列",     selection: $array)
                lookupPicker("行列 10",  selection: $array10)
                lookupPicker("筆順五碼", selection: $wb)
                lookupPicker("華象直覺", selection: $hs)
                lookupPicker("拼音",     selection: $pinyin)
            }
        }
        .navigationTitle("字根反查設定")
    }

    private func lookupPicker(_ label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(0..<lookupValues.count, id: \.self) { i in
                Text(lookupLabels[i]).tag(lookupValues[i])
            }
        }
        .pickerStyle(.menu)
    }
}
