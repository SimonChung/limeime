import UIKit

// Full keyboard extension entry point.
// Implements IMService behavior per IM_SERVICE.md spec.

final class KeyboardViewController: UIInputViewController {

    // MARK: - Components
    private var candidateBar: CandidateBarView!
    private var keyboardView:  KeyboardView!

    // MARK: - SearchServer
    private var searchServer: SearchServer?
    private var db: LimeDB?
    private var lastKnownRestoreTimestamp: Double = 0

    // MARK: - Composing State (spec §3)
    private var mComposing:      String = ""  // current composing code buffer
    private var composingLength: Int    = 0   // chars inserted inline (iOS composing sim §12)
    private var mPredictionOn:   Bool   = true
    private var mCompletionOn:   Bool   = false

    // MARK: - Candidate State (spec §3)
    private var selectedCandidate:  Mapping? = nil
    private var committedCandidate: Mapping? = nil
    private var mCandidateList:     [Mapping] = []
    private var hasCandidatesShown: Bool = false
    /// True when the candidate bar is currently showing related phrases (for "More" expansion).
    private var isShowingRelatedPhrases: Bool = false

    // MARK: - Mode State (spec §3)
    private var mEnglishOnly: Bool = false
    private var mCapsLock:    Bool = false
    private var isShiftOn:    Bool = false
    private var activeIM:     String = "phonetic"
    // Sentinel ID "__unset__" ensures initOnStartInput always loads the JSON layout on first call,
    // even when the JSON id matches the hardcoded fallback id ("lime_phonetic").
    private var currentLayout: LimeKeyLayout = LimeKeyLayout(id: "__unset__", rows: [])

    // MARK: - English Prediction (spec §7 — iOS: UITextChecker replaces custom dict)
    private var tempEnglishWord: String = ""
    private let textChecker = UITextChecker()

    // MARK: - Auto-Commit (spec §3)
    private var autoCommit: Int = 0  // 0 = off; >0 = auto-commit at that composing length

    // MARK: - Settings (spec §15 — read from shared UserDefaults)
    /// Raw `keyboard_theme` value (0–5 = explicit palette; 6 = follow system appearance).
    private var currentKeyboardTheme:    Int  = 0
    private var hanConvertOption:        Int  = 0     // 0=off, 1=T→S, 2=S→T
    private var autoChineseSymbol:       Bool = false // show Chinese punctuation after commit
    private var sortSuggestions:         Bool = false
    private var smartChineseInput:       Bool = false // runtime phrase suggestion
    private var learnPhrase:             Bool = true  // enable LD phrase learning
    private var englishPredictionOn:     Bool = true  // enable English prediction
    private var selkeyOption:            Int  = 0     // 0=none, 1=prepend, 2=prepend+space
    private var hasVibration:            Bool = false
    private var hasSound:                Bool = false
    private var mPersistentLanguageMode: Bool = false // persist English/Chinese mode
    private var phoneticKeyboardType:    String = "phonetic"

    // MARK: - Activated IM Cycling (spec §10)
    private var activatedIMs:  [ImConfig] = []
    private var activeIMIndex: Int        = 0

    // MARK: - Chinese Punctuation (spec §11)
    private var hasChineseSymbolCandidatesShown: Bool = false

    // MARK: - Symbol Keyboard (spec §10)
    private var isSymbolMode:       Bool = false
    private var symbolPageIndex:    Int  = 0  // 0 = lime_number_symbol, 1 = shift variant
    private let symbolLayouts = ["lime_number_symbol", "lime_number_symbol_shift"]
    // Layout to restore when leaving symbol mode
    private var preSymbolLayout: LimeKeyLayout? = nil

    // MARK: - LD Composing Buffer (spec §5, §8)
    private var LDComposingBuffer: String = ""

    // MARK: - Search Thread Management (spec §6 Thread Interruption)
    private var currentSearchID: UInt64 = 0

    // MARK: - Self-Update Guard (spec §12)
    // Set true around our own insertText/deleteBackward calls to suppress textDidChange checks
    private var isSelfUpdate = false

    // MARK: - Key Preview
    private weak var keyPreviewView: UIView?

    // MARK: - Composing Popup (mirrors Android mComposingTextPopup, spec §6)
    // A thin collapsible strip ABOVE the candidate bar that shows the IM
    // keyname (e.g. "日月" for Dayi "dj"). Height is 0 when idle so it takes
    // zero vertical space — candidates keep their full width.
    private var composingPopupLabel: UILabel!
    private var composingPopupHeightConstraint: NSLayoutConstraint!
    private let composingPopupHeight: CGFloat = 22

    // MARK: - Keyboard Geometry
    private let candidateBarHeight: CGFloat = 44
    // keyRowHeight removed — height is now driven by KeyboardView.preferredHeight,
    // which sums actual per-row heights (54 pt regular, 56 pt bottom row).
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private weak var inlineMenuPanel: UIView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        if let loaded = LayoutLoader.load("lime_phonetic") { currentLayout = loaded }
        LayoutLoader.prefetchCommonLayouts()
        setupKeyboardUI()
        applyHeight()
        // Run DB setup off the main thread — avoids blocking the keyboard's view
        // lifecycle and prevents the Settings watchdog from killing the Preferences
        // app (0x8BADF00D) when it presents the keyboard extension for the first time.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupDatabase()
        }
    }

    /// Called every time the keyboard becomes visible (spec §2 initOnStartInput).
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload database if Settings app performed a restore while the keyboard was inactive.
        // After restore, the keyboard's DatabaseQueue points to the old (replaced) file.
        let restoredAt = UserDefaults(suiteName: "group.net.toload.limeime")?
            .double(forKey: "lime_db_restored_at") ?? 0
        if restoredAt > lastKnownRestoreTimestamp {
            lastKnownRestoreTimestamp = restoredAt
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.setupDatabase()
            }
        }
        initOnStartInput()
    }

    /// Called every time the keyboard is dismissed — equivalent to Android postFinishInput().
    /// Triggers deferred LD phrase learning (spec §9 Tier 2).
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let ss = searchServer {
            DispatchQueue.global(qos: .background).async {
                ss.learnLDPhrase()
            }
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Use screen bounds to detect orientation — NOT view.bounds.
        // The keyboard extension view is always wider than tall (e.g. 430 × 270pt),
        // so view.bounds.width > view.bounds.height is always true and would
        // permanently force landscape row heights and horizontal label layout.
        let screen = UIScreen.main.bounds
        let landscape = screen.width > screen.height
        keyboardView?.isLandscape = landscape
        applyHeight()
        updateGlobeKeyVisibility()
    }

    // MARK: - Trait / Theme Change (spec §2)

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let prev = previousTraitCollection else { return }

        // Theme change (light ↔ dark): keyboard background updates automatically via system colors,
        // but we need to refresh the keyboard view to pick up any color-dependent resources.
        // When keyboard_theme == 6 (系統設定), resolvedKeyboardTheme re-evaluates here so the
        // palette switches automatically as the user toggles system appearance.
        if prev.userInterfaceStyle != traitCollection.userInterfaceStyle {
            keyboardView?.setLayout(currentLayout)
        }

        // Horizontal size class change (e.g. iPad split-screen, landscape):
        // reset composing and reload the layout.
        if prev.horizontalSizeClass != traitCollection.horizontalSizeClass {
            cancelComposing()
            updateGlobeKeyVisibility()
            applyHeight()
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // Nothing — detection deferred to textDidChange
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Guard: skip checks triggered by our own insertText/deleteBackward (spec §12)
        guard !isSelfUpdate else { return }
        // If the cursor changed externally while composing, cancel composing
        if composingLength > 0 {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            if !before.hasSuffix(mComposing) {
                cancelComposing()
            }
        }
        updateShiftForAutoCap()
    }

    // MARK: - Initialization (spec §2 initOnStartInput)

    private func initOnStartInput() {
        // If the container app modified IM records (score/code/word), clear the stale cache
        // so the first keystroke re-queries from the updated DB.
        if sharedDefaults?.bool(forKey: "needsKeyboardCacheReset") == true {
            searchServer?.clearAllCaches()
            sharedDefaults?.removeObject(forKey: "needsKeyboardCacheReset")
        }

        mCompletionOn = false
        mCapsLock     = false

        // Map keyboard type → mEnglishOnly + mPredictionOn (spec §2 table)
        switch textDocumentProxy.keyboardType ?? .default {
        case .numberPad, .decimalPad, .asciiCapableNumberPad:
            mEnglishOnly = true; mPredictionOn = true
        case .phonePad:
            mEnglishOnly = true; mPredictionOn = true
        case .emailAddress, .URL:
            mEnglishOnly = true; mPredictionOn = false
        default:
            // Restore persisted language mode if enabled (spec §15)
            if mPersistentLanguageMode {
                mEnglishOnly = sharedDefaults?.bool(forKey: "persisted_english_mode") ?? false
            } else {
                mEnglishOnly = false
            }
            mPredictionOn = true
        }

        // Restore last-used LIME IM (mirrors Android mLIMEPref.getActiveIM(), key "keyboard_list")
        if !mEnglishOnly {
            let saved = sharedDefaults?.string(forKey: "keyboard_list") ?? ""
            if !saved.isEmpty && saved != activeIM {
                // Find the saved IM in the activated list and restore index
                if let idx = activatedIMs.firstIndex(where: { $0.tableNick == saved }) {
                    activeIM      = saved
                    activeIMIndex = idx
                    if let db = self.db {
                        let caps = imCapabilities(for: activeIM, db: db)
                        searchServer?.setTableName(activeIM,
                            hasNumberMapping: caps.hasNumber,
                            hasSymbolMapping: caps.hasSymbol)
                    } else {
                        searchServer?.setTableName(activeIM)
                    }
                    searchServer?.setPhoneticKeyboardType(phoneticKeyboardType)
                }
            }
        }

        let layoutName = mEnglishOnly ? "lime_english" : "lime_\(activeIM)"
        if let newLayout = LayoutLoader.load(layoutName) ?? LayoutLoader.load("lime_phonetic"),
           newLayout.id != currentLayout.id {
            currentLayout = newLayout
            keyboardView?.setLayout(currentLayout)
            applyHeight()
        }

        clearComposing(force: false)
        tempEnglishWord = ""
    }

    // MARK: - Database Setup

    private func setupDatabase() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.toload.limeime")
        else { return }

        let dbPath = containerURL.appendingPathComponent("lime.db").path

        // Copy bundled lime.db to App Group container on first launch
        if !FileManager.default.fileExists(atPath: dbPath) {
            copyBundledDB(to: dbPath)
        }

        guard let limeDB = try? LimeDB(path: dbPath) else { return }

        // Auto-import phonetic (and seedDefaultIMs) FIRST — this is the heavy I/O work
        // that must stay off the main thread.
        importPhoneticIfNeeded(db: limeDB, containerURL: containerURL)
        importRelatedIfNeeded(db: limeDB)

        // Build the activated IM list off-thread (DB reads only)
        let allIMs = (try? limeDB.getAllImConfigs()) ?? []
        let kbState = UserDefaults(suiteName: "group.net.toload.limeime")?.string(forKey: "keyboard_state") ?? ""
        var resolved: [ImConfig]
        if kbState.isEmpty {
            resolved = allIMs.filter { $0.enabled }
        } else {
            let enabled = Set(kbState.components(separatedBy: ","))
            resolved = allIMs.filter { enabled.contains($0.tableNick) }
        }
        if resolved.isEmpty { resolved = allIMs.filter { $0.enabled } }
        if resolved.isEmpty { resolved = buildFallbackIMList(db: limeDB) }

        let firstNick = resolved.first?.tableNick ?? allIMs.first(where: { $0.enabled })?.tableNick ?? "phonetic"
        let resolvedIM = firstNick.isEmpty ? "phonetic" : firstNick
        let caps = imCapabilities(for: resolvedIM, db: limeDB)
        let ss = SearchServer(db: limeDB)
        ss.setTableName(resolvedIM, hasNumberMapping: caps.hasNumber, hasSymbolMapping: caps.hasSymbol)

        // Marshal all state assignments back to the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.db           = limeDB
            self.searchServer = ss
            self.activatedIMs  = resolved
            self.activeIM      = resolvedIM
            self.activeIMIndex = 0
            // Load settings from shared UserDefaults (spec §15)
            self.loadSettings()
            self.searchServer?.setPhoneticKeyboardType(self.phoneticKeyboardType)
            self.searchServer?.sortSuggestions = self.sortSuggestions
            self.applyFeedbackSettings()
        }
    }

    /// Build an activatedIMs list directly from IM data tables that have rows.
    /// Used as a fallback when the im table is empty (first launch before any import).
    private func buildFallbackIMList(db: LimeDB) -> [ImConfig] {
        let candidates: [(nick: String, label: String, keyboard: String)] = [
            ("phonetic", "注音",     "lime_phonetic"),
            ("dayi",     "大易",     "lime_dayi"),
            ("cj",       "倉頡",     "lime_cj"),
            ("cj5",      "倉頡五代", "lime_cj"),
            ("array",    "行列",     "lime_array"),
            ("array10",  "行列十",   "lime_array10"),
            ("wb",       "筆順五碼", "lime_wb"),
            ("hs",       "許氏",     "lime_hs"),
            ("ez",       "輕鬆",     "lime_ez"),
            ("scj",      "速成",     "lime_cj"),
            ("ecj",      "易倉頡",   "lime_cj"),
        ]
        var idx: Int64 = 0
        return candidates.compactMap { (nick, label, keyboard) in
            guard db.tableHasData(nick) else { return nil }
            defer { idx += 1 }
            return ImConfig(id: idx, imName: nick, tableNick: nick, label: label,
                            keyboardId: keyboard, keyboardLandscapeId: keyboard,
                            enabled: true, sortOrder: Int(idx))
        }
    }

    /// Shared UserDefaults for reading settings written by the container app.
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.net.toload.limeime")
    }

    /// Load all user preferences from shared UserDefaults (spec §15).
    /// Returns the resolved theme index (0–5), mapping value 6 (系統設定) to 0 (淺色) or 1 (深色)
    /// based on the current UITraitCollection. Callers use this when applying colour palettes.
    var resolvedKeyboardTheme: Int {
        if currentKeyboardTheme == 6 {
            return traitCollection.userInterfaceStyle == .dark ? 1 : 0
        }
        return currentKeyboardTheme
    }

    private func loadSettings() {
        let d = sharedDefaults
        currentKeyboardTheme = d?.integer(forKey: "keyboard_theme") ?? 0
        hanConvertOption     = d?.integer(forKey: "hanConvertOption")     ?? 0
        autoChineseSymbol    = d?.bool(forKey: "autoChineseSymbol")       ?? false
        sortSuggestions      = d?.bool(forKey: "sortSuggestions")         ?? false
        smartChineseInput    = d?.bool(forKey: "smartChineseInput")       ?? false
        learnPhrase          = d?.bool(forKey: "learnPhrase")             ?? true
        englishPredictionOn  = d?.bool(forKey: "englishPrediction")       ?? true
        selkeyOption         = d?.integer(forKey: "selkeyOption")         ?? 0
        hasVibration         = d?.bool(forKey: "hasVibration")            ?? false
        hasSound             = d?.bool(forKey: "hasSound")                ?? false
        mPersistentLanguageMode = d?.bool(forKey: "persistentLanguageMode") ?? false
        phoneticKeyboardType = d?.string(forKey: "phonetic_keyboard_type") ?? "phonetic"
        autoCommit           = d?.integer(forKey: "auto_commit")          ?? 0
    }

    /// Push feedback settings to KeyboardView (spec §15).
    private func applyFeedbackSettings() {
        keyboardView?.feedbackVibration = hasVibration
        keyboardView?.feedbackSound     = hasSound
    }

    private func copyBundledDB(to destPath: String) {
        guard let srcURL = Bundle.main.url(forResource: "lime", withExtension: "db") else { return }
        try? FileManager.default.copyItem(at: srcURL, to: URL(fileURLWithPath: destPath))
    }

    private func importPhoneticIfNeeded(db: LimeDB, containerURL: URL) {
        // Use tableHasData (not tableExists): bundled lime.db pre-creates all tables as empty shells.
        // Only import if the phonetic table genuinely has no data.
        guard !db.tableHasData("phonetic") else { return }
        guard let srcURL = Bundle.main.url(forResource: "phonetic", withExtension: "db") else { return }
        try? db.importFromAttachedDB(sourcePath: srcURL.path, tableName: "phonetic")
        try? db.seedDefaultIMs()
        searchServer?.clearAllCaches()
    }

    private func importRelatedIfNeeded(db: LimeDB) {
        guard !db.tableHasData("related") else { return }
        guard let srcURL = Bundle.main.url(forResource: "lime", withExtension: "db") else { return }
        db.importDbRelated(srcURL)
    }

    /// Determine whether an IM's code table uses digit and/or symbol characters.
    /// The phonetic family (and similar tone-based IMs) use digits 0-9 for initials/tones
    /// and symbols like ;, /, ., - for finals. Non-phonetic IMs (Cangjie, Array, etc.)
    /// typically use only letters.
    private func imCapabilities(for imCode: String,
                                db: LimeDB) -> (hasNumber: Bool, hasSymbol: Bool) {
        let lc = imCode.lowercased()
        // Phonetic family: standard phonetic, ETEN 26/41, HSU, Dayi — all use digits+symbols
        let phoneticFamily = ["phonetic", "et26", "et_41", "eten", "hsu", "hs", "dayi", "ez"]
        if phoneticFamily.contains(where: { lc.hasPrefix($0) }) {
            return (hasNumber: true, hasSymbol: true)
        }
        // Stroke5 (wb) uses only letters
        // Cangjie (cj), Array, EZ, etc. — detect from DB
        return db.detectIMCapabilities(tableName: imCode)
    }

    // MARK: - UI Setup

    private func setupKeyboardUI() {
        // Transparent so the area above the candidate bar (the collapsible
        // popup strip) doesn't paint a gray rectangle next to the keyname bubble.
        view.backgroundColor = .clear

        // Composing keyname strip (collapsible, 0pt height when idle).
        // Background matches the candidate bar so the popup reads as part of it.
        composingPopupLabel = UILabel()
        composingPopupLabel.translatesAutoresizingMaskIntoConstraints = false
        composingPopupLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        composingPopupLabel.textColor = .label
        composingPopupLabel.textAlignment = .left
        composingPopupLabel.backgroundColor = UIColor.systemGray6
        composingPopupLabel.isHidden = true
        composingPopupLabel.clipsToBounds = true
        composingPopupLabel.layer.cornerRadius = 4
        view.addSubview(composingPopupLabel)
        composingPopupHeightConstraint = composingPopupLabel.heightAnchor.constraint(equalToConstant: 0)

        // Candidate bar
        candidateBar = CandidateBarView()
        candidateBar.delegate = self
        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateBar)

        // Keyboard view
        keyboardView = KeyboardView(layout: currentLayout)
        keyboardView.delegate = self
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            composingPopupLabel.topAnchor.constraint(equalTo: view.topAnchor),
            composingPopupLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            composingPopupLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -6),
            composingPopupHeightConstraint,

            candidateBar.topAnchor.constraint(equalTo: composingPopupLabel.bottomAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: candidateBarHeight),

            keyboardView.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // Space-key gestures (swipe + long-press) are now added directly in
        // KeyboardView.makeKeyButton so they survive every setLayout() call.
    }

    private func applyHeight() {
        // Use KeyboardView.preferredHeight so the outer extension view is sized to
        // exactly match the sum of each row's actual height (54 pt regular, 56 pt
        // bottom row), rather than a flat per-row constant that would squish keys.
        let keysHeight = keyboardView?.preferredHeight ?? CGFloat(currentLayout.rows.count) * 54
        let popupHeight = composingPopupHeightConstraint?.constant ?? 0
        let totalHeight = popupHeight + candidateBarHeight + keysHeight
        if let existing = keyboardHeightConstraint {
            existing.constant = totalHeight
        } else {
            let c = view.heightAnchor.constraint(equalToConstant: totalHeight)
            c.priority = UILayoutPriority(rawValue: 999)
            c.isActive = true
            keyboardHeightConstraint = c
        }
    }

    // MARK: - Key Event Dispatch (spec §4 onKey)

    private func onKey(primaryCode: Int) {
        // CapsLock pre-processing: lowercase → uppercase (spec §4)
        var code = primaryCode
        if mCapsLock && code >= 97 && code <= 122 { code -= 32 }

        switch code {
        case LimeKeyCode.delete.rawValue:      handleBackspace()
        case LimeKeyCode.shift.rawValue:       handleShift()
        case LimeKeyCode.done.rawValue:        handleClose()
        case LimeKeyCode.globe.rawValue:       advanceToNextInputMode()
        case LimeKeyCode.switchToEnglish.rawValue: switchChiEng(toEnglish: true)
        case LimeKeyCode.switchToIM.rawValue:  switchChiEng(toEnglish: false)
        case LimeKeyCode.switchToSymbol.rawValue:     switchToSymbol()
        case LimeKeyCode.switchSymbolKeyboard.rawValue: cycleSymbolPage()
        case LimeKeyCode.nextIM.rawValue:      switchToNextActivatedIM(forward: true)
        case LimeKeyCode.prevIM.rawValue:      switchToNextActivatedIM(forward: false)
        case LimeKeyCode.space.rawValue:       handleEnterOrSpace(isEnter: false)
        case LimeKeyCode.enter.rawValue:       handleEnterOrSpace(isEnter: true)
        default:
            // Selkey routing: if candidates shown and key matches a selection key (spec §6)
            if hasCandidatesShown && !mEnglishOnly && tryPickBySelkey(code: code) { break }
            handleCharacter(code)
            // Auto-commit check (spec §5)
            if autoCommit > 0, !mEnglishOnly,
               mComposing.count == autoCommit,
               searchServer?.isPhoneticTable == true {
                commitTyped()
            }
        }
    }

    // MARK: - Space / Enter Handling (spec §4)

    private func handleEnterOrSpace(isEnter: Bool) {
        let isPhonetic = searchServer?.isPhoneticTable ?? false

        // Determine whether to pick the highlighted candidate (spec §4 conditions)
        let shouldPick: Bool
        if isEnter {
            shouldPick = hasCandidatesShown
        } else if mEnglishOnly {
            shouldPick = false
        } else if !isPhonetic {
            shouldPick = hasCandidatesShown
        } else {
            // Phonetic: pick if composing ends with space (tone entered) or composing is empty
            shouldPick = hasCandidatesShown && (mComposing.hasSuffix(" ") || mComposing.isEmpty)
        }

        if shouldPick {
            let picked = pickHighlightedCandidate()
            if !picked && mComposing.isEmpty {
                clearSuggestions()
                textDocumentProxy.insertText(isEnter ? "\n" : " ")
            }
        } else {
            // Not picking — for phonetic space is a tone marker
            if !isEnter, !mEnglishOnly, isPhonetic, !mComposing.isEmpty {
                handleCharacter(LimeKeyCode.space.rawValue)  // space as tone mark
            } else {
                textDocumentProxy.insertText(isEnter ? "\n" : " ")
            }
        }
    }

    // MARK: - Character Handling (spec §5 handleCharacter / Character Acceptance Rules)

    private func handleCharacter(_ code: Int) {
        guard code > 0, let scalar = Unicode.Scalar(code) else { return }
        let char      = Character(scalar)
        let charStr   = String(char)

        if mEnglishOnly {
            handleEnglishCharacter(code: code, char: char)
            return
        }

        let hasSymbol  = searchServer?.hasSymbolMapping ?? false
        let hasNumber  = searchServer?.hasNumberMapping ?? false
        let isPhonetic = searchServer?.isPhoneticTable ?? false
        let isLetter   = (code >= 97 && code <= 122) || (code >= 65 && code <= 90)
        let isDigit    = code >= 48 && code <= 57
        let isSpace    = code == 32
        let isComma    = code == 44
        let isPeriod   = code == 46

        // Acceptance rules (spec §5 table)
        let accepted: Bool
        if !hasSymbol && !hasNumber {
            accepted = isLetter || (isPhonetic && isSpace) || isComma || isPeriod
        } else if !hasSymbol && hasNumber {
            accepted = isLetter || isDigit
        } else if hasSymbol && !hasNumber {
            let isSymbol = !isLetter && !isDigit && code > 32
            accepted = isLetter || isSymbol || (isPhonetic && isSpace)
        } else {
            let isSymbol = !isLetter && !isDigit && code > 32
            accepted = isLetter || isDigit || isSymbol || (isPhonetic && isSpace)
        }

        if accepted {
            let insertChar = (isShiftOn && !isSpace) ? charStr.uppercased() : charStr

            // Stroke5 (WB) 5-character limit: discard the 6th character (spec §5)
            if searchServer?.isWBTable == true && mComposing.count >= 5 { return }

            // Append to composing buffer first, then insert (so textDidChange check passes)
            mComposing += insertChar
            // iOS composing simulation: insert char inline (spec §12)
            isSelfUpdate = true
            textDocumentProxy.insertText(insertChar)
            isSelfUpdate = false
            composingLength += 1
            // WB: truncate query code to 5 characters
            updateCandidates()
        } else {
            // Not accepted: commit current candidate, then send char directly (spec §5)
            _ = pickHighlightedCandidate()
            let insertChar = isShiftOn ? charStr.uppercased() : charStr
            isSelfUpdate = true
            textDocumentProxy.insertText(insertChar)
            isSelfUpdate = false
            finishComposing()
        }

        // One-shot shift: auto-reset after a character (caps lock stays)
        if isShiftOn && !mCapsLock && code != LimeKeyCode.shift.rawValue { setShift(false) }
    }

    // MARK: - English Character Handling (spec §5 English Mode)

    private func handleEnglishCharacter(code: Int, char: Character) {
        let charStr    = String(char)
        let insertChar = isShiftOn ? charStr.uppercased() : charStr

        if char.isLetter {
            tempEnglishWord += insertChar
        } else {
            resetTempEnglishWord()
        }
        isSelfUpdate = true
        textDocumentProxy.insertText(insertChar)
        isSelfUpdate = false
        updateEnglishPrediction()
        if isShiftOn && !mCapsLock { setShift(false) }   // one-shot reset
    }

    // MARK: - Backspace Handling (spec §5 handleBackspace — 6 cases)

    private func handleBackspace() {
        if mComposing.count > 1 {
            // Case 1: composing > 1 → remove last char from composing, then delete from document
            // (update mComposing BEFORE deleteBackward so textDidChange check passes)
            mComposing.removeLast()
            isSelfUpdate = true
            textDocumentProxy.deleteBackward()
            isSelfUpdate = false
            composingLength -= 1
            updateCandidates()
            showComposingPopup()

        } else if mComposing.count == 1 {
            // Case 2: composing == 1 → clear composing and force-remove from document (spec §5)
            clearComposing(force: true)

        } else if hasCandidatesShown && hasChineseSymbolCandidatesShown {
            // Case 4: Chinese punctuation list shown → hide it without deleting (spec §11)
            hasChineseSymbolCandidatesShown = false
            hasCandidatesShown  = false
            selectedCandidate   = nil
            mCandidateList      = []
            candidateBar.setCandidates([])

        } else if hasCandidatesShown {
            // Case 3: composing empty, candidates shown → clear (spec §5 clearComposing(false))
            clearComposing(force: false)

        } else if mEnglishOnly && !tempEnglishWord.isEmpty {
            // Case 5: English prediction word → delete last char and re-query
            tempEnglishWord.removeLast()
            isSelfUpdate = true
            textDocumentProxy.deleteBackward()
            isSelfUpdate = false
            updateEnglishPrediction()

        } else {
            // Case 6: no composing, no candidates → pass delete to text field
            textDocumentProxy.deleteBackward()
        }
    }

    // MARK: - Shift / CapsLock (spec §4 handleShift)
    // Three states matching Android: off → one-shot (on) → caps lock → off
    // Layout switching: normal ↔ _shift variant (mirrors Android toggleShift())

    private func handleShift() {
        if mCapsLock {
            // Caps lock → off
            mCapsLock = false
            isShiftOn = false
            applyShiftState()
        } else if isShiftOn {
            // One-shot → caps lock
            mCapsLock = true
            isShiftOn = true
            applyShiftState()
        } else {
            // Off → one-shot
            isShiftOn = true
            applyShiftState()
        }
    }

    /// Apply the current shift/capsLock state to the keyboard view (icon) and layout.
    private func applyShiftState() {
        // Update shift key icon (3 states)
        let state: KeyboardView.ShiftState = mCapsLock ? .capsLock : (isShiftOn ? .on : .off)
        keyboardView?.setShiftState(state)

        // Switch to shift layout variant when active, normal variant when off.
        // Mirrors Android mKeyboardSwitcher.toggleShift().
        // Only switch for layouts that have a _shift variant (abc, phonetic, etc.).
        let wantShift = isShiftOn || mCapsLock
        let base      = currentLayout.id.hasSuffix("_shift")
                        ? String(currentLayout.id.dropLast(6))  // already shifted → get base
                        : currentLayout.id
        let targetId  = wantShift ? "\(base)_shift" : base
        if targetId != currentLayout.id,
           let newLayout = LayoutLoader.load(targetId) {
            currentLayout = newLayout
            keyboardView?.setLayout(currentLayout)
            applyHeight()
        }
    }

    private func setShift(_ on: Bool) {
        isShiftOn = on
        applyShiftState()
    }

    private func handleClose() {
        clearComposing(force: false)
        dismissKeyboard()
    }

    private func updateShiftForAutoCap() {
        // Auto-capitalization only applies in English mode.
        // In Chinese/phonetic mode the composing codes are always lowercase —
        // auto-shifting them to uppercase breaks all DB lookups.
        guard mEnglishOnly else { return }
        guard !isShiftOn, !mCapsLock else { return }
        // iOS provides autocapitalizationType directly (spec §2 iOS note)
        guard let capType = textDocumentProxy.autocapitalizationType,
              capType == .sentences || capType == .allCharacters || capType == .words else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let atStart = before.isEmpty || before.hasSuffix(". ") || before.hasSuffix("! ") || before.hasSuffix("? ")
        if atStart {
            isShiftOn = true
            applyShiftState()
        }
    }

    // MARK: - iOS Composing Simulation (spec §12)

    /// Clear composing state. `force=true` removes inline chars from the document.
    private func clearComposing(force: Bool) {
        if force {
            isSelfUpdate = true
            for _ in 0..<composingLength { textDocumentProxy.deleteBackward() }
            isSelfUpdate = false
        }
        mComposing       = ""
        composingLength  = 0
        selectedCandidate = nil
        mCandidateList   = []
        hasCandidatesShown = false
        hasChineseSymbolCandidatesShown = false
        candidateBar.setComposingCode("")
        candidateBar.setCandidates([])
        hideComposingPopup()
    }

    /// Cancel composing without touching the document (cursor moved externally).
    private func cancelComposing() {
        mComposing       = ""
        composingLength  = 0
        selectedCandidate = nil
        mCandidateList   = []
        hasCandidatesShown = false
        hasChineseSymbolCandidatesShown = false
        candidateBar.setComposingCode("")
        candidateBar.setCandidates([])
        hideComposingPopup()
    }

    /// Reset composing tracking after text has been committed or cleared.
    private func finishComposing() {
        mComposing       = ""
        composingLength  = 0
        selectedCandidate = nil
        hasCandidatesShown = false
        hideComposingPopup()
    }

    // MARK: - Candidate Flow (spec §6 updateCandidates)

    private func updateCandidates() {
        guard mPredictionOn, let ss = searchServer, !mComposing.isEmpty else {
            clearSuggestions(); return
        }
        // Show composing popup IMMEDIATELY (don't wait for async DB query).
        // Mirrors Android: the popup is based on keyToKeyname(mComposing), independent of candidate results.
        showComposingPopup()
        // On composing restart (length == 1): clear runtime suggestion context (spec §6)
        if mComposing.count == 1 && smartChineseInput {
            ss.clearSuggestionContext()
        }
        // WB/Stroke5: query with at most 5 characters (spec §5)
        let code = ss.isWBTable ? String(mComposing.prefix(5)) : mComposing
        currentSearchID &+= 1
        let sid = currentSearchID

        let doRuntime = smartChineseInput
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            var results = ss.getMappingByCode(code, isSoftKeyboard: true)
            if !results.isEmpty {
                // Emoji injection at position 3 (spec §6 step 5)
                let emojiType = LimeDB.EMOJI_TW  // default: Traditional Chinese emoji set
                results = ss.injectEmoji(into: results, code: code, type: emojiType, insertAt: 3)
                if doRuntime {
                    results = ss.makeRunTimeSuggestion(code: code, currentList: results)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.currentSearchID == sid else { return }
                results.isEmpty ? self.clearSuggestions() : self.setSuggestions(results)
            }
        }
    }

    /// Set candidate list and default selection (spec §6 Default Candidate Selection).
    private func setSuggestions(_ list: [Mapping]) {
        mCandidateList     = list
        hasCandidatesShown = !list.isEmpty
        isShowingRelatedPhrases = false

        // If index 1 is an exact match, select it (skips the composing echo at index 0)
        if list.count > 1 && list[1].isExactMatchToCodeRecord {
            selectedCandidate = list[1]
        } else {
            selectedCandidate = list.first(where: { !$0.isComposingCodeRecord })
        }

        // Mixed mode (spec §6, Android CandidateView.setComposingText):
        // - Show keyname popup ABOVE the candidate bar (e.g. "日土" for Dayi "dj")
        // - Keep the composing code record VISIBLE in the candidate bar at index 0
        //   so the user can tap it to commit the raw English letters.
        showComposingPopup()
        showCandidates(list)                        // include composing code record
    }

    /// Show candidates in the bar, applying current selkey config (spec §6).
    private func showCandidates(_ list: [Mapping]) {
        let selkey = searchServer?.getSelkey() ?? "1234567890"
        candidateBar.setSelkeyConfig(selkeys: selkey, option: selkeyOption)
        candidateBar.setCandidates(list)
    }

    private func clearSuggestions() {
        // Auto Chinese Symbol: when candidates disappear in Chinese mode, show punctuation (spec §11)
        if autoChineseSymbol && !mEnglishOnly && hasCandidatesShown && !hasChineseSymbolCandidatesShown {
            let punctuation = KeyboardViewController.chinesePunctuationMappings()
            if !punctuation.isEmpty {
                mCandidateList              = punctuation
                hasCandidatesShown          = true
                hasChineseSymbolCandidatesShown = true
                selectedCandidate           = nil
                showCandidates(punctuation)
                return
            }
        }
        hasChineseSymbolCandidatesShown = false
        isShowingRelatedPhrases = false
        mCandidateList     = []
        hasCandidatesShown = false
        selectedCandidate  = nil
        candidateBar.setCandidates([])
        // Keep the keyname popup visible while the user is still composing.
        // clearSuggestions() runs both when composing is fully cleared AND when
        // the DB returns zero matches during an ongoing composition — only the
        // former should tear down the popup.
        if mComposing.isEmpty {
            hideComposingPopup()
        }
    }

    private func keyname(_ code: String) -> String {
        searchServer?.keyToKeyname(code) ?? code
    }

    // MARK: - Composing Popup (mirrors Android mComposingTextPopup)

    /// Show the IM keyname in the thin strip above the candidate bar.
    /// Strip expands from 0 → composingPopupHeight only when we have a keyname,
    /// so candidates get full horizontal width when idle.
    private func showComposingPopup() {
        let raw = mComposing
        guard !raw.isEmpty, !mEnglishOnly else { hideComposingPopup(); return }

        let name = keyname(raw)
        // Only show when keyname actually differs from raw code (matches Android)
        guard name.uppercased() != raw.uppercased(),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            hideComposingPopup()
            return
        }
        composingPopupLabel.text = " \(name) "
        composingPopupLabel.isHidden = false
        if composingPopupHeightConstraint.constant != composingPopupHeight {
            composingPopupHeightConstraint.constant = composingPopupHeight
            view.layoutIfNeeded()
            applyHeight()
        }
    }

    private func hideComposingPopup() {
        composingPopupLabel.text = nil
        composingPopupLabel.isHidden = true
        if composingPopupHeightConstraint.constant != 0 {
            composingPopupHeightConstraint.constant = 0
            view.layoutIfNeeded()
            applyHeight()
        }
    }

    // MARK: - Candidate Selection (spec §8)

    /// Pick the highlighted candidate. Returns true if a candidate was committed.
    @discardableResult
    private func pickHighlightedCandidate() -> Bool {
        guard let candidate = selectedCandidate else { return false }
        pickCandidateManually(candidate)
        return true
    }

    private func pickCandidateManually(_ candidate: Mapping) {
        let wasComposingCodeCommit = candidate.isComposingCodeRecord
        selectedCandidate = candidate
        commitTyped()
        if wasComposingCodeCommit {
            // Mixed-mode raw-English commit: no related phrases; clear the bar
            // (updateRelatedPhrase bails for composing-code records without clearing).
            clearSuggestions()
        } else {
            updateRelatedPhrase()
        }
    }

    // MARK: - Commit Flow (spec §8 commitTyped)

    private func commitTyped() {
        guard let candidate = selectedCandidate else { return }

        // Unicode surrogate / emoji: commit directly and force-clear (spec §8)
        let isEmoji = candidate.isEmojiRecord || containsEmojiSurrogatePair(candidate.word)

        // iOS composing simulation: delete composing chars, then insert word (spec §12 step 5)
        // isSelfUpdate suppresses textDidChange composing-integrity check during our own writes
        isSelfUpdate = true
        for _ in 0..<composingLength { textDocumentProxy.deleteBackward() }

        // Han conversion: iOS uses CFStringTransform (spec §8 step 3)
        var wordToCommit = candidate.word
        if hanConvertOption == 1 {
            // Traditional → Simplified
            let mutable = NSMutableString(string: wordToCommit)
            CFStringTransform(mutable, nil, "Hant-Hans" as CFString, false)
            wordToCommit = mutable as String
        } else if hanConvertOption == 2 {
            // Simplified → Traditional
            let mutable = NSMutableString(string: wordToCommit)
            CFStringTransform(mutable, nil, "Hans-Hant" as CFString, false)
            wordToCommit = mutable as String
        }

        // Commit the word (spec §8 step 4)
        textDocumentProxy.insertText(wordToCommit)
        isSelfUpdate = false

        // Continuous typing check (spec §8 step 6)
        let codeLen = searchServer?.getRealCodeLength(
            mapping: candidate, composing: mComposing) ?? min(candidate.code.count, mComposing.count)

        // Emoji or WB/punctuation: force-clear after commit (spec §8)
        let forceClearAfterCommit = isEmoji
            || candidate.isChinesePunctuationRecord
            || (searchServer?.isWBTable == true)

        if mComposing.count > candidate.code.count && !forceClearAfterCommit {
            // Remaining composing code → re-establish inline and re-query
            var remaining = String(mComposing.dropFirst(min(codeLen, mComposing.count)))
            if remaining.hasPrefix(" ") { remaining = String(remaining.dropFirst()) }
            mComposing      = remaining
            composingLength = remaining.count
            if !remaining.isEmpty {
                isSelfUpdate = true
                textDocumentProxy.insertText(remaining)
                isSelfUpdate = false
                updateCandidates()
                showComposingPopup()
                // Buffer for LD learning (spec §5 Continuous Typing)
                if learnPhrase { searchServer?.addLDPhrase(candidate, ending: false) }
                // Track LD composing buffer (spec §5)
                if LDComposingBuffer.isEmpty { LDComposingBuffer = candidate.word }
                else { LDComposingBuffer += candidate.word }
                return
            }
        }

        // Post-commit (spec §8 step 7)
        committedCandidate = candidate
        if forceClearAfterCommit {
            clearComposing(force: true)
            LDComposingBuffer = ""
            if learnPhrase { searchServer?.addLDPhrase(nil, ending: true) }
        } else {
            finishComposing()
            // Signal LD learning end if buffer had accumulated
            if !LDComposingBuffer.isEmpty {
                if learnPhrase { searchServer?.addLDPhrase(candidate, ending: true) }
                LDComposingBuffer = ""
            }
        }
        if learnPhrase { searchServer?.learnRelatedPhraseAndUpdateScore(candidate) }
        // Record committed candidate + its code for runtime phrase suggestion cross-check (spec §6)
        if smartChineseInput { searchServer?.addToSuggestionContext(candidate, code: candidate.code) }

        // Reverse lookup notification — show code list briefly in composing bar (spec §8, §13)
        if let ss = searchServer {
            let word = candidate.word
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let result = ss.getCodeListStringFromWord(word), !result.isEmpty else { return }
                DispatchQueue.main.async { self?.showToast(result) }
            }
        }
    }

    // MARK: - Related Phrase Display (spec §8 updateRelatedPhrase)

    private func updateRelatedPhrase(getAllRecords: Bool = false) {
        guard let committed = committedCandidate,
              !committed.word.isEmpty,
              !committed.isEmojiRecord,
              !committed.isChinesePunctuationRecord,
              !committed.isComposingCodeRecord,   // mixed-mode raw-code commit has no related phrases
              let ss = searchServer else { return }

        // Clear stale composing candidates immediately so the bar doesn't linger.
        // Only when no remaining composing; if commitTyped() left a partial buffer,
        // updateCandidates() owns the bar.
        if mComposing.isEmpty {
            mCandidateList          = []
            hasCandidatesShown      = false
            isShowingRelatedPhrases = false
            selectedCandidate       = nil
            candidateBar.setCandidates([])
            candidateBar.setComposingCode("")
        }

        let word = committed.word
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let related = ss.getRelatedByWord(word, getAllRecords: getAllRecords)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.mComposing.isEmpty else { return }
                if related.isEmpty {
                    // spec §8 step 6: no related results → nil committedCandidate, clear bar
                    self.committedCandidate = nil
                    self.clearSuggestions()
                } else {
                    self.mCandidateList         = related
                    self.hasCandidatesShown     = true
                    self.isShowingRelatedPhrases = true
                    self.selectedCandidate      = related.first
                    self.showCandidates(related)
                }
            }
        }
    }

    // MARK: - English Prediction (spec §7 — iOS: UITextChecker)

    private func updateEnglishPrediction() {
        guard englishPredictionOn else { return }
        guard !tempEnglishWord.isEmpty else { clearSuggestions(); return }
        let word = tempEnglishWord
        // Validate cursor context (spec §7) — read documentContext on main thread
        let beforeCursor = textDocumentProxy.documentContextBeforeInput ?? ""
        guard beforeCursor.hasSuffix(word) else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let range = NSRange(location: 0, length: (word as NSString).length)
            let completions = self.textChecker.completions(
                forPartialWordRange: range, in: word, language: "en_US") ?? []
            var mappings: [Mapping] = completions.prefix(20).map { suggestion in
                Mapping(id: 0, code: word, word: suggestion,
                        score: 0, baseScore: 0, recordType: Mapping.RecordType.englishSuggestion)
            }
            // Emoji injection for English predictions (spec §6 step 5, §7)
            if !mappings.isEmpty, let ss = self.searchServer {
                mappings = ss.injectEmoji(into: mappings, code: word, type: LimeDB.EMOJI_EN, insertAt: 3)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if mappings.isEmpty { self.clearSuggestions() }
                else {
                    self.mCandidateList    = mappings
                    self.hasCandidatesShown = true
                    self.selectedCandidate = mappings.first
                    self.showCandidates(mappings)
                }
            }
        }
    }

    private func resetTempEnglishWord() { tempEnglishWord = "" }

    /// Commit an English suggestion: insert only the untyped suffix + space (spec §8 Path 3).
    private func commitEnglishSuggestion(_ word: String) {
        let suffix = word.count > tempEnglishWord.count
            ? String(word.dropFirst(tempEnglishWord.count)) : ""
        textDocumentProxy.insertText(suffix + " ")
        resetTempEnglishWord()
        clearSuggestions()
    }

    // MARK: - Mode Switching (spec §10)

    /// Toggle Chinese ↔ English mode (spec §10 switchChiEng).
    private func switchChiEng(toEnglish: Bool) {
        if isSymbolMode { exitSymbolMode() }
        clearComposing(force: false)
        mEnglishOnly = toEnglish
        // Persist language mode if setting is enabled (spec §15)
        if mPersistentLanguageMode {
            sharedDefaults?.set(toEnglish, forKey: "persisted_english_mode")
        }
        clearSuggestions()
        resetTempEnglishWord()
        let layoutName = toEnglish ? "lime_english" : "lime_phonetic"
        if let loaded = LayoutLoader.load(layoutName) { currentLayout = loaded }
        keyboardView.setLayout(currentLayout)
        applyHeight()
    }

    /// Cycle to next/previous LIME-internal IM (spec §10 switchToNextActivatedIM).
    private func switchToNextActivatedIM(forward: Bool) {
        guard !activatedIMs.isEmpty, let ss = searchServer else { return }
        let count = activatedIMs.count
        activeIMIndex = forward
            ? (activeIMIndex + 1) % count
            : (activeIMIndex - 1 + count) % count
        let im = activatedIMs[activeIMIndex]
        activeIM = im.tableNick.isEmpty ? "phonetic" : im.tableNick
        // Persist last-used IM (mirrors Android mLIMEPref.setActiveIM(), key "keyboard_list")
        sharedDefaults?.set(activeIM, forKey: "keyboard_list")

        // Clear composing and candidates before switching
        clearComposing(force: false)
        LDComposingBuffer = ""

        // Reconfigure SearchServer for the new IM
        if let db = self.db {
            let caps = imCapabilities(for: activeIM, db: db)
            ss.setTableName(activeIM, hasNumberMapping: caps.hasNumber, hasSymbolMapping: caps.hasSymbol)
        } else {
            ss.setTableName(activeIM)
        }
        ss.setPhoneticKeyboardType(phoneticKeyboardType)

        // Update keyboard layout to match the new IM if available
        let preferredLayout = "lime_\(activeIM)"
        if let newLayout = LayoutLoader.load(preferredLayout), newLayout.id != currentLayout.id {
            currentLayout = newLayout
            keyboardView?.setLayout(currentLayout)
            applyHeight()
        }
    }

    // MARK: - Symbol Keyboard (spec §10)

    /// Enter symbol keyboard mode (spec §10 switchToSymbol).
    private func switchToSymbol() {
        guard !isSymbolMode else { cycleSymbolPage(); return }
        isSymbolMode    = true
        symbolPageIndex = 0
        preSymbolLayout = currentLayout
        clearComposing(force: false)
        loadSymbolLayout(page: 0)
    }

    /// Cycle through symbol keyboard pages (spec §10 KEYCODE_SWITCH_SYMBOL_KEYBOARD).
    private func cycleSymbolPage() {
        guard isSymbolMode else { switchToSymbol(); return }
        symbolPageIndex = (symbolPageIndex + 1) % symbolLayouts.count
        loadSymbolLayout(page: symbolPageIndex)
    }

    /// Load a symbol keyboard layout page.
    private func loadSymbolLayout(page: Int) {
        let id = symbolLayouts[page]
        let layout = LayoutLoader.load(id) ?? currentLayout
        currentLayout = layout
        keyboardView?.setLayout(layout)
        applyHeight()
    }

    /// Exit symbol mode and restore the previous keyboard layout.
    private func exitSymbolMode() {
        guard isSymbolMode else { return }
        isSymbolMode = false
        let restore = preSymbolLayout ?? currentLayout
        currentLayout = restore
        keyboardView?.setLayout(restore)
        applyHeight()
    }

    // MARK: - Globe Key Visibility (spec §10)

    /// The keyboard key (code -3) is always visible — it is the primary dismiss affordance
    /// and doubles as the long-press globe menu entry point (spec §10).
    /// Only legacy code-200 globe keys (hardcoded fallback layouts) are conditionally shown.
    private func updateGlobeKeyVisibility() {
        keyboardView?.setGlobeKeyVisible(needsInputModeSwitchKey)
    }

    // MARK: - Selkey (spec §6)

    /// Try to pick a candidate by selkey index. Returns true if a candidate was picked.
    @discardableResult
    private func tryPickBySelkey(code: Int) -> Bool {
        guard selkeyOption > 0 else { return false }
        let selkey = searchServer?.getSelkey() ?? "1234567890"
        guard let scalar = Unicode.Scalar(code),
              let idx = selkey.firstIndex(of: Character(scalar)) else { return false }
        let offset = selkey.distance(from: selkey.startIndex, to: idx)
        // Filter out composing-code echo to get real candidates
        let realCandidates = mCandidateList.filter { !$0.isComposingCodeRecord }
        guard offset < realCandidates.count else { return false }
        pickCandidateManually(realCandidates[offset])
        return true
    }

    // MARK: - Emoji / Surrogate Pair Detection (spec §8)

    /// Returns true if the string contains a Unicode surrogate pair (emoji or extended CJK).
    private func containsEmojiSurrogatePair(_ word: String) -> Bool {
        word.unicodeScalars.contains { $0.value > 0xFFFF }
    }

    // MARK: - Toast Notification (spec §8, §13)

    private var toastTimer: Timer?

    /// Briefly display a message in the composing-code label (spec §8 reverse-lookup notification).
    private func showToast(_ message: String) {
        toastTimer?.invalidate()
        candidateBar.setComposingCode(message)
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.candidateBar.setComposingCode("")
        }
    }

    // MARK: - Chinese Punctuation List (spec §11)

    /// Standard Chinese punctuation set shown after a commit when autoChineseSymbol is on.
    static func chinesePunctuationMappings() -> [Mapping] {
        let symbols = ["，", "。", "、", "；", "：", "？", "！",
                       "「", "」", "『", "』", "【", "】", "〔", "〕",
                       "（", "）", "《", "》", "〈", "〉",
                       "…", "——", "～", "·", "※",
                       "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}"]
        return symbols.map {
            Mapping(id: 0, code: "", word: $0, score: 0, baseScore: 0,
                    recordType: Mapping.RecordType.chinesePunctuation)
        }
    }

    // MARK: - Space Key Gestures (spec §10)
    // Space-key gestures (swipe left/right and long-press) are wired directly in
    // KeyboardView.makeKeyButton — no setup needed here.
}

// MARK: - KeyboardViewDelegate
extension KeyboardViewController: KeyboardViewDelegate {

    func keyboardView(_ view: KeyboardView, didPress keyDef: KeyDef) {
        onKey(primaryCode: keyDef.code)
    }

    // MARK: Key preview (iOS callout popup above pressed key)

    func keyboardView(_ view: KeyboardView, showPreviewFor keyDef: KeyDef, keyRect: CGRect) {
        keyPreviewView?.removeFromSuperview()

        // At least label or sublabel must be non-empty
        guard !keyDef.label.isEmpty || !keyDef.sublabel.isEmpty else { return }

        // Convert key rect from KeyboardView → window coordinates so the preview
        // can float above the keyboard top edge without being clipped by self.view.
        guard let kbView = keyboardView,
              let window = self.view.window else { return }
        let keyInWindow = kbView.convert(keyRect, to: window)

        // --- Layout mode: mirror key rendering (same isTall logic as KeyboardView) ---
        let isTall = keyInWindow.height >= keyInWindow.width

        // --- Bubble geometry -------------------------------------------------
        let isLand  = view.isLandscape
        let bubbleW = max(keyInWindow.width + 8, isLand ? 44.0 : 52.0)
        let bubbleH = max(keyInWindow.height * 1.5, isLand ? 50.0 : 68.0)
        let tipH    = 8.0
        let totalH  = bubbleH + tipH
        let r       = 10.0

        // Centre bubble above the key; clamp to window edges
        let bubbleX = max(4, min(keyInWindow.midX - bubbleW / 2,
                                 window.bounds.width - bubbleW - 4))
        let bubbleY = max(4, keyInWindow.minY - totalH)   // clamp so tip stays visible

        let container = UIView(frame: CGRect(x: bubbleX, y: bubbleY,
                                             width: bubbleW, height: totalH))
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false

        // --- Callout shape ---------------------------------------------------
        let tipCenterX = keyInWindow.midX - bubbleX
        let tipX = max(r, min(tipCenterX, bubbleW - r))

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: r))
        path.addArc(withCenter: CGPoint(x: r, y: r),
                    radius: r, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: bubbleW - r, y: 0))
        path.addArc(withCenter: CGPoint(x: bubbleW - r, y: r),
                    radius: r, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bubbleW, y: bubbleH - r))
        path.addArc(withCenter: CGPoint(x: bubbleW - r, y: bubbleH - r),
                    radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: tipX + 6, y: bubbleH))
        path.addLine(to: CGPoint(x: tipX,     y: bubbleH + tipH))
        path.addLine(to: CGPoint(x: tipX - 6, y: bubbleH))
        path.addLine(to: CGPoint(x: r, y: bubbleH))
        path.addArc(withCenter: CGPoint(x: r, y: bubbleH - r),
                    radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.close()

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        shapeLayer.shadowOpacity = 0.22
        shapeLayer.shadowRadius  = 3
        container.layer.addSublayer(shapeLayer)

        // --- Content: same layout as the key itself --------------------------
        let contentView: UIView
        let hasSublabel = !keyDef.sublabel.isEmpty

        if hasSublabel {
            // Dual-label layout — mirrors KeyboardView.makeDualLabelView
            let stack = UIStackView()
            stack.alignment = .center

            let primaryLbl = UILabel()
            primaryLbl.text = keyDef.label
            primaryLbl.textColor = .secondaryLabel
            primaryLbl.setContentHuggingPriority(.required, for: .horizontal)
            primaryLbl.setContentHuggingPriority(.required, for: .vertical)

            let subLbl = UILabel()
            subLbl.text = keyDef.sublabel
            subLbl.textColor = .label
            subLbl.setContentHuggingPriority(.required, for: .horizontal)
            subLbl.setContentHuggingPriority(.required, for: .vertical)

            if isTall {
                stack.axis    = .vertical
                stack.spacing = 0
                primaryLbl.font = UIFont.systemFont(ofSize: isLand ? 12 : 13, weight: .regular)
                subLbl.font     = UIFont.systemFont(ofSize: isLand ? 22 : 28, weight: .regular)
            } else {
                stack.axis    = .horizontal
                stack.spacing = 3
                primaryLbl.font = UIFont.systemFont(ofSize: isLand ? 11 : 12, weight: .light)
                subLbl.font     = UIFont.systemFont(ofSize: isLand ? 16 : 20, weight: .regular)
            }
            stack.addArrangedSubview(primaryLbl)
            stack.addArrangedSubview(subLbl)
            contentView = stack
        } else {
            // Single label
            let lbl = UILabel()
            lbl.text          = keyDef.label
            lbl.font          = UIFont.systemFont(ofSize: isLand ? 20 : 26, weight: .regular)
            lbl.textColor     = .label
            lbl.textAlignment = .center
            contentView = lbl
        }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: container.centerYAnchor,
                                                  constant: -tipH / 2),
            contentView.widthAnchor.constraint(lessThanOrEqualToConstant: bubbleW - 8),
        ])

        // --- Animate in -------------------------------------------------------
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        window.addSubview(container)   // add to window so preview clears the candidate bar
        UIView.animate(withDuration: 0.08, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            container.alpha = 1
            container.transform = .identity
        }
        keyPreviewView = container
    }

    func keyboardViewDismissPreview(_ view: KeyboardView) {
        guard let preview = keyPreviewView else { return }
        keyPreviewView = nil
        UIView.animate(withDuration: 0.08, animations: {
            preview.alpha = 0
        }, completion: { _ in preview.removeFromSuperview() })
    }

    func keyboardView(_ view: KeyboardView, didLongPress keyDef: KeyDef) {
        // Keyboard key (code -3) and legacy globe key (code -200): show iOS+LIME options menu (spec §10).
        // Per spec §10: briefly show globe icon preview to satisfy Apple's globe affordance requirement,
        // then display the inline options menu.
        if keyDef.code == LimeKeyCode.done.rawValue || keyDef.code == LimeKeyCode.globe.rawValue {
            showGlobeKeyPreview(for: keyDef, in: view)
            showGlobeMenu(from: view)
        }
        // Space key: show LIME-internal IM picker only (spec §10: NOT iOS keyboard switch)
        else if keyDef.code == LimeKeyCode.space.rawValue {
            showLimeIMPicker()
        }
    }

    // MARK: - IM Switching Helper

    /// Switch to a LIME-internal IM by absolute index in activatedIMs.
    private func switchIM(toIndex i: Int) {
        guard i < activatedIMs.count else { return }
        let im = activatedIMs[i]
        activeIMIndex = i
        activeIM = im.tableNick.isEmpty ? "phonetic" : im.tableNick
        // Persist last-used IM (mirrors Android mLIMEPref.setActiveIM(), key "keyboard_list")
        sharedDefaults?.set(activeIM, forKey: "keyboard_list")
        clearComposing(force: false)
        if let db = self.db {
            let caps = imCapabilities(for: activeIM, db: db)
            searchServer?.setTableName(activeIM, hasNumberMapping: caps.hasNumber,
                                       hasSymbolMapping: caps.hasSymbol)
        } else {
            searchServer?.setTableName(activeIM)
        }
        searchServer?.setPhoneticKeyboardType(phoneticKeyboardType)
        if let layout = LayoutLoader.load("lime_\(activeIM)"), layout.id != currentLayout.id {
            currentLayout = layout
            keyboardView?.setLayout(currentLayout)
            applyHeight()
        }
    }

    /// Show a globe-icon preview bubble above the keyboard key on long-press (spec §10).
    /// The globe icon satisfies Apple's "clearly visible globe affordance" requirement.
    private func showGlobeKeyPreview(for keyDef: KeyDef, in kbView: KeyboardView) {
        guard let window = self.view.window,
              let kbViewUnwrapped = keyboardView else { return }

        // Find the done key button frame in window coordinates
        // We look for the subview whose KeyDef code matches -3
        var keyRect: CGRect = .zero
        func findKeyRect(in view: UIView) -> CGRect? {
            for sub in view.subviews {
                if let btn = sub as? UIButton {
                    // Use reflection-free approach: check tag or just use kbView bounds estimate
                    // Since we can't directly access KeyButton.keyDef from here,
                    // approximate: the done key is always the first key in the bottom row.
                    _ = btn
                }
                if let found = findKeyRect(in: sub) { return found }
            }
            return nil
        }

        // Approximate position: done key is bottom-left of the keyboard
        let kbInWindow = kbViewUnwrapped.convert(kbViewUnwrapped.bounds, to: window)
        let isLand = kbView.isLandscape
        let approxKeyW: CGFloat = kbInWindow.width * 0.15   // 15%p width
        let approxKeyH: CGFloat = isLand ? 38 : 56
        keyRect = CGRect(x: kbInWindow.minX,
                         y: kbInWindow.maxY - approxKeyH,
                         width: approxKeyW,
                         height: approxKeyH)

        // Build a simple globe preview bubble
        let bubbleW: CGFloat = isLand ? 44 : 52
        let bubbleH: CGFloat = isLand ? 50 : 64
        let tipH: CGFloat = 8
        let totalH = bubbleH + tipH
        let r: CGFloat = 10
        let bubbleX = max(4, keyRect.midX - bubbleW / 2)
        let bubbleY = max(4, keyRect.minY - totalH)

        let container = UIView(frame: CGRect(x: bubbleX, y: bubbleY,
                                             width: bubbleW, height: totalH))
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false

        // Shape
        let tipX: CGFloat = min(bubbleW - r, max(r, keyRect.midX - bubbleX))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: r))
        path.addArc(withCenter: CGPoint(x: r, y: r), radius: r,
                    startAngle: .pi, endAngle: -.pi/2, clockwise: true)
        path.addLine(to: CGPoint(x: bubbleW - r, y: 0))
        path.addArc(withCenter: CGPoint(x: bubbleW - r, y: r), radius: r,
                    startAngle: -.pi/2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bubbleW, y: bubbleH - r))
        path.addArc(withCenter: CGPoint(x: bubbleW - r, y: bubbleH - r), radius: r,
                    startAngle: 0, endAngle: .pi/2, clockwise: true)
        path.addLine(to: CGPoint(x: tipX + 6, y: bubbleH))
        path.addLine(to: CGPoint(x: tipX, y: bubbleH + tipH))
        path.addLine(to: CGPoint(x: tipX - 6, y: bubbleH))
        path.addLine(to: CGPoint(x: r, y: bubbleH))
        path.addArc(withCenter: CGPoint(x: r, y: bubbleH - r), radius: r,
                    startAngle: .pi/2, endAngle: .pi, clockwise: true)
        path.close()
        let sl = CAShapeLayer()
        sl.path = path.cgPath; sl.fillColor = UIColor.white.cgColor
        sl.shadowColor = UIColor.black.cgColor; sl.shadowOffset = CGSize(width: 0, height: 1)
        sl.shadowOpacity = 0.22; sl.shadowRadius = 3
        container.layer.addSublayer(sl)

        // Globe SF symbol
        let img = UIImageView(image: UIImage(systemName: "globe",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: isLand ? 22 : 28)))
        img.tintColor = .label
        img.contentMode = .center
        img.frame = CGRect(x: 0, y: 0, width: bubbleW, height: bubbleH)
        container.addSubview(img)

        container.alpha = 0
        window.addSubview(container)
        UIView.animate(withDuration: 0.08) { container.alpha = 1 }

        // Auto-dismiss after menu appears (brief flash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            UIView.animate(withDuration: 0.1, animations: { container.alpha = 0 },
                           completion: { _ in container.removeFromSuperview() })
        }
    }

    // MARK: - Inline Menu Panel
    // UIAlertController.present() in a keyboard extension causes the system to advance to the
    // next input mode in some iOS versions. Use an inline UIView panel instead.

    /// Dismiss any visible inline menu panel.
    private func dismissInlineMenu() {
        inlineMenuPanel?.removeFromSuperview()
        inlineMenuPanel = nil
    }

    /// Build and show an inline menu panel overlaying the keyboard.
    private func showInlineMenu(items: [(title: String, action: () -> Void)]) {
        dismissInlineMenu()
        guard let root = view else { return }

        let panel = UIView()
        panel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.97)
        panel.layer.cornerRadius = 12
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.2
        panel.layer.shadowRadius = 8
        panel.layer.shadowOffset = CGSize(width: 0, height: -2)
        panel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(panel)

        // Stack of buttons
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        for (idx, item) in items.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(item.title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            btn.contentHorizontalAlignment = .center
            btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
            btn.tag = idx
            // Separator line (except last)
            if idx < items.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor.separator
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(btn)
                stack.addArrangedSubview(sep)
            } else {
                // Last item is Cancel — style differently
                btn.setTitleColor(.systemBlue, for: .normal)
                stack.addArrangedSubview(btn)
            }
            let capture = item.action
            btn.addAction(UIAction { [weak self] _ in
                self?.dismissInlineMenu()
                capture()
            }, for: .touchUpInside)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),

            panel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            panel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            panel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
        ])

        // Tap outside to dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissInlineMenuGesture))
        tap.cancelsTouchesInView = false
        root.addGestureRecognizer(tap)

        inlineMenuPanel = panel

        // Animate in
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.2) {
            panel.alpha = 1
            panel.transform = .identity
        }
    }

    @objc private func dismissInlineMenuGesture(_ gr: UITapGestureRecognizer) {
        guard let panel = inlineMenuPanel else { return }
        // Only dismiss if tap is outside the panel
        let loc = gr.location(in: view)
        if !panel.frame.contains(loc) {
            dismissInlineMenu()
        }
        view?.removeGestureRecognizer(gr)
    }

    /// Long-press on keyboard key: inline options menu (spec §10).
    private func showGlobeMenu(from sourceView: UIView) {
        var items: [(title: String, action: () -> Void)] = []

        // iOS system keyboard switch — only when needsInputModeSwitchKey (spec §10)
        if needsInputModeSwitchKey {
            items.append(("切換系統輸入法", { [weak self] in self?.advanceToNextInputMode() }))
        }

        // LIME-internal IM list
        for (i, im) in activatedIMs.enumerated() {
            let label = im.label.isEmpty ? im.tableNick : im.label
            let display = (i == activeIMIndex) ? "✓ \(label)" : label
            items.append((display, { [weak self] in self?.switchIM(toIndex: i) }))
        }

        // Han conversion
        let hanLabels = ["漢字轉換：關閉", "漢字轉換：繁→簡", "漢字轉換：簡→繁"]
        for (opt, title) in hanLabels.enumerated() {
            let display = (hanConvertOption == opt) ? "✓ \(title)" : title
            items.append((display, { [weak self] in
                self?.hanConvertOption = opt
                self?.sharedDefaults?.set(opt, forKey: "hanConvertOption")
            }))
        }

        items.append(("取消", {}))
        showInlineMenu(items: items)
    }

    /// Long-press on space key: LIME-internal IM picker (spec §10).
    private func showLimeIMPicker() {
        guard !activatedIMs.isEmpty else { return }
        var items: [(title: String, action: () -> Void)] = []
        for (i, im) in activatedIMs.enumerated() {
            let label = im.label.isEmpty ? im.tableNick : im.label
            let display = (i == activeIMIndex) ? "✓ \(label)" : label
            items.append((display, { [weak self] in self?.switchIM(toIndex: i) }))
        }
        items.append(("取消", {}))
        showInlineMenu(items: items)
    }
}

// MARK: - CandidateBarViewDelegate
extension KeyboardViewController: CandidateBarViewDelegate {

    func candidateBarView(_ view: CandidateBarView, didSelect mapping: Mapping) {
        if mapping.isEnglishSuggestionRecord {
            commitEnglishSuggestion(mapping.word)
        } else {
            pickCandidateManually(mapping)
        }
    }

    func candidateBarViewDidRequestMore(_ view: CandidateBarView) {
        // spec §8: when showing related phrases, expand via related query not composing query
        if isShowingRelatedPhrases {
            updateRelatedPhrase(getAllRecords: true)
            return
        }
        guard let ss = searchServer, !mComposing.isEmpty else { return }
        let more = ss.getMappingByCode(mComposing, getAllRecords: true)
        mCandidateList = more
        hasCandidatesShown = !more.isEmpty
        showCandidates(more)   // include composing code record for mixed-mode commit
    }
}
