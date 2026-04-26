import Foundation

// Static catalog of all downloadable input methods.
// Source: Android's SetupImLoadDialog.java button configs + LIME.java cloud URLs.
// Base URL: https://github.com/lime-ime/limeime/raw/master/Database/

// MARK: - Models

struct IMFamily: Identifiable, Hashable {
    let id: String           // unique key
    let chineseName: String  // e.g. "注音"
    let englishName: String  // e.g. "Phonetic"
    let description: String  // one-line description
    let systemIcon: String   // SF Symbol name
    let variants: [IMVariant]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: IMFamily, r: IMFamily) -> Bool { l.id == r.id }
}

struct IMVariant: Identifiable, Hashable {
    let id: String           // unique key (also used as a stable identifier)
    let name: String         // display name, e.g. "標準"
    let filename: String     // file in Database/ folder (zip or limedb)
    let tableName: String    // SQLite table name to import into
    let imName: String       // im.im_name value
    let label: String        // im.label value
    let keyboardId: String   // im.keyboard_id
    let recordCount: Int     // approximate number of entries
    let compressedKB: Int    // approximate download size in KB
    let isLimeDB: Bool       // true = .limedb (attach directly), false = .zip (extract first)

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: IMVariant, r: IMVariant) -> Bool { l.id == r.id }

    static let baseURL = "https://github.com/lime-ime/limeime/raw/master/Database/"

    var downloadURL: URL {
        URL(string: Self.baseURL + filename)!
    }

    var sizeString: String {
        compressedKB < 1024
            ? "\(compressedKB) KB"
            : String(format: "%.1f MB", Double(compressedKB) / 1024)
    }
}

// MARK: - Catalog

enum IMCatalog {

    static let families: [IMFamily] = [
        .init(
            id: "phonetic",
            chineseName: "注音",
            englishName: "Phonetic / BPMF",
            description: "標準注音符號，適合台灣使用者",
            systemIcon: "character.phonetic",
            variants: [
                .init(id: "phonetic",              name: "標準",       filename: "phonetic.zip",              tableName: "phonetic", imName: "phonetic",         label: "注音",      keyboardId: "phonetic",  recordCount: 34_838,  compressedKB: 589,  isLimeDB: false),
                .init(id: "phoneticbig5",          name: "Big5",       filename: "phoneticbig5.zip",          tableName: "phonetic", imName: "phonetic",         label: "注音",      keyboardId: "phonetic",  recordCount: 34_838,  compressedKB: 465,  isLimeDB: false),
                .init(id: "phoneticcomplete",      name: "進階",       filename: "phoneticcomplete.zip",      tableName: "phonetic", imName: "phonetic",         label: "注音",      keyboardId: "phonetic",  recordCount: 400_000, compressedKB: 2900, isLimeDB: false),
                .init(id: "phoneticcompletebig5",  name: "進階 Big5",  filename: "phoneticcompletebig5.zip",  tableName: "phonetic", imName: "phonetic",         label: "注音",      keyboardId: "phonetic",  recordCount: 400_000, compressedKB: 2400, isLimeDB: false),
            ]
        ),
        .init(
            id: "cj",
            chineseName: "倉頡",
            englishName: "Cangjie",
            description: "倉頡輸入法，多種字集選擇",
            systemIcon: "square.grid.2x2",
            variants: [
                .init(id: "cj",     name: "第五代",    filename: "cj.zip",     tableName: "cj",  imName: "cj",   label: "倉頡五代", keyboardId: "cj",  recordCount: 28_596, compressedKB: 830,  isLimeDB: false),
                .init(id: "cjbig5", name: "Big5",      filename: "cjbig5.zip", tableName: "cj",  imName: "cj",   label: "倉頡五代", keyboardId: "cj",  recordCount: 13_859, compressedKB: 506,  isLimeDB: false),
                .init(id: "cjhk",   name: "香港",      filename: "cjhk.zip",   tableName: "cj",  imName: "cj",   label: "倉頡五代", keyboardId: "cj",  recordCount: 30_278, compressedKB: 884,  isLimeDB: false),
                .init(id: "cj5",    name: "CJ5",       filename: "cj5.zip",    tableName: "cj5", imName: "cj5",  label: "倉頡五代", keyboardId: "cj",  recordCount: 24_004, compressedKB: 491,  isLimeDB: false),
                .init(id: "scj",    name: "速成",      filename: "scj.zip",    tableName: "scj", imName: "scj",  label: "速成",     keyboardId: "cj",  recordCount: 74_250, compressedKB: 1400, isLimeDB: false),
                .init(id: "ecj",    name: "ECJ",       filename: "ecj.zip",    tableName: "ecj", imName: "ecj",  label: "ECJ",      keyboardId: "cj",  recordCount: 13_119, compressedKB: 136,  isLimeDB: false),
                .init(id: "ecjhk",  name: "ECJ 香港",  filename: "ecjhk.zip",  tableName: "ecj", imName: "ecj",  label: "ECJ HK",   keyboardId: "cj",  recordCount: 27_853, compressedKB: 210,  isLimeDB: false),
            ]
        ),
        .init(
            id: "dayi",
            chineseName: "大易",
            englishName: "Dayi",
            description: "大易輸入法，支援統一碼字集",
            systemIcon: "textformat.alt",
            variants: [
                .init(id: "dayi",     name: "標準",     filename: "dayi.zip",     tableName: "dayi", imName: "dayi",  label: "大易",     keyboardId: "dayisym", recordCount: 18_638,  compressedKB: 486, isLimeDB: false),
                .init(id: "dayiuni",  name: "統一碼",   filename: "dayiuni.zip",  tableName: "dayi", imName: "dayi",  label: "大易",     keyboardId: "dayisym", recordCount: 27_198,  compressedKB: 584, isLimeDB: false),
                .init(id: "dayiunip", name: "統一碼全", filename: "dayiunip.zip", tableName: "dayi", imName: "dayi",  label: "大易",     keyboardId: "dayisym", recordCount: 117_766, compressedKB: 2700, isLimeDB: false),
            ]
        ),
        .init(
            id: "ez",
            chineseName: "輕鬆",
            englishName: "EZ",
            description: "輕鬆輸入法",
            systemIcon: "hand.tap",
            variants: [
                .init(id: "ez", name: "標準", filename: "ez.zip", tableName: "ez", imName: "ez", label: "輕鬆", keyboardId: "ez", recordCount: 14_422, compressedKB: 237, isLimeDB: false),
            ]
        ),
        .init(
            id: "array",
            chineseName: "行列",
            englishName: "Array (行列30)",
            description: "行列輸入法 30 鍵標準版",
            systemIcon: "table",
            variants: [
                // Source: Android LIME.java DATABASE_CLOUD_IM_ARRAY.
                // The Android URL uses array.limedb but that file wraps a long Android
                // cache path (storage/emulated/0/Android/data/.../array.db) inside a zip.
                // array.zip in the same Database/ folder is a cleaner zip wrapping a bare
                // "array.db" — prefer that for the iOS unzip + attach pipeline.
                .init(id: "array", name: "標準", filename: "array.zip",
                      tableName: "array", imName: "array", label: "行列30",
                      keyboardId: "array", recordCount: 32_386, compressedKB: 524,
                      isLimeDB: false),
            ]
        ),
        .init(
            id: "array10",
            chineseName: "行列10",
            englishName: "Array 10 (行列10)",
            description: "行列輸入法 10 鍵版本 (電話鍵盤)",
            systemIcon: "table.badge.more",
            variants: [
                // Source: Android LIME.java DATABASE_CLOUD_IM_ARRAY10.
                // Android uses array10.limedb which wraps a long cache path; we use
                // array10.zip for the clean filename. Array and Array10 are separate
                // IMs with different tableName / imName (matches Android IM_ARRAY10).
                .init(id: "array10", name: "標準", filename: "array10.zip",
                      tableName: "array10", imName: "array10", label: "行列10",
                      keyboardId: "phone_simple", recordCount: 32_120, compressedKB: 558,
                      isLimeDB: false),
            ]
        ),
        .init(
            id: "wb",
            chineseName: "筆順",
            englishName: "WB (Stroke)",
            description: "筆順五碼輸入法",
            systemIcon: "pencil.and.outline",
            variants: [
                .init(id: "wb", name: "筆順五碼", filename: "wb.zip", tableName: "wb", imName: "wb", label: "筆順", keyboardId: "wb", recordCount: 26_378, compressedKB: 267, isLimeDB: false),
            ]
        ),
        .init(
            id: "hs",
            chineseName: "華象",
            englishName: "HS",
            description: "華象直覺輸入法，多種版本",
            systemIcon: "wand.and.stars",
            variants: [
                .init(id: "hs",  name: "完整版", filename: "hs.zip",  tableName: "hs", imName: "hs", label: "華象", keyboardId: "hs", recordCount: 183_659, compressedKB: 3600, isLimeDB: false),
                .init(id: "hs1", name: "V1",    filename: "hs1.zip", tableName: "hs", imName: "hs", label: "華象", keyboardId: "hs", recordCount: 50_845,  compressedKB: 830,  isLimeDB: false),
                .init(id: "hs2", name: "V2",    filename: "hs2.zip", tableName: "hs", imName: "hs", label: "華象", keyboardId: "hs", recordCount: 50_838,  compressedKB: 834,  isLimeDB: false),
                .init(id: "hs3", name: "V3",    filename: "hs3.zip", tableName: "hs", imName: "hs", label: "華象", keyboardId: "hs", recordCount: 64_324,  compressedKB: 1000, isLimeDB: false),
            ]
        ),
        .init(
            id: "pinyin",
            chineseName: "拼音",
            englishName: "Pinyin",
            description: "漢語拼音輸入法",
            systemIcon: "text.bubble",
            variants: [
                .init(id: "pinyin",   name: "標準",  filename: "pinyin.zip",   tableName: "pinyin", imName: "pinyin", label: "拼音",      keyboardId: "pinyin", recordCount: 34_753, compressedKB: 509, isLimeDB: false),
                .init(id: "pinyingb", name: "國標",  filename: "pinyingb.zip", tableName: "pinyin", imName: "pinyin", label: "拼音 (GB)", keyboardId: "pinyin", recordCount: 34_753, compressedKB: 502, isLimeDB: false),
            ]
        ),
        // 自建輸入法 — no cloud download; local import only (§13.3)
        .init(
            id: "custom",
            chineseName: "自建",
            englishName: "Custom",
            description: "使用者自建輸入法，匯入 .limedb 或 .cin/.lime 檔案",
            systemIcon: "person.crop.rectangle",
            variants: []
        ),
    ]

    /// Flat list of all variants for search
    static var allVariants: [IMVariant] {
        families.flatMap { $0.variants }
    }
}
