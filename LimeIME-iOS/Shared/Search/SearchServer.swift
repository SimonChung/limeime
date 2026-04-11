import Foundation

// IM query engine: receives input codes from KeyboardViewController,
// queries lime.db for candidates, manages scoring, caching, and phrase learning.
// Port target: SearchServer.java (~1,500 lines)

final class SearchServer {

    private let db: LimeDB
    private var currentTableName: String = ""

    // MARK: - IM Capability Flags (spec §13 setTableName)
    private(set) var hasNumberMapping: Bool = false
    private(set) var hasSymbolMapping: Bool = false
    private var cachedSelkey: String = "1234567890"

    // MARK: - Sort preference (spec §15 sortSuggestions)
    /// When true, candidates are ordered by (score + basescore) DESC (default DB behaviour).
    /// When false, candidates are returned in DB insertion order (code-alphabetical).
    var sortSuggestions: Bool = true

    // MARK: - Caches
    private var mappingCache:   [String: [Mapping]] = [:]
    private var relatedCache:   [String: [Mapping]] = [:]  // related phrases as Mapping
    private var blacklistCache: Set<String> = []
    private let cacheLock    = NSLock()
    private let maxCacheEntries = 1024

    // Score constants
    private let scoreAdjustmentIncrement = 50
    private let maxScoreThreshold        = 200
    private let minScoreThreshold        = 120

    // MARK: - Learning State (spec §9)
    private var lastCommittedMapping: Mapping? = nil   // previous commit for RP learning
    private var ldPhraseList:      [Mapping]    = []   // current accumulating LD phrase
    private var ldPhraseListArray: [[Mapping]]  = []   // completed LD phrases pending write
    private let learnLock = NSLock()

    private var prefetchThread: Thread?

    init(db: LimeDB) {
        self.db = db
    }

    // MARK: - IM Selection (spec §13 setTableName)

    /// Set the phonetic keyboard variant for code remapping (spec §5).
    /// Pass "phonetic", "et_41", "et26", or "hsu".
    func setPhoneticKeyboardType(_ type: String) {
        db.phoneticKeyboardType = type
        clearAllCaches()
    }

    /// Switch IM table and update capability flags. Clears caches and triggers prefetch.
    func setTableName(_ name: String, hasNumberMapping: Bool = false, hasSymbolMapping: Bool = false) {
        self.hasNumberMapping = hasNumberMapping
        self.hasSymbolMapping = hasSymbolMapping
        cachedSelkey = db.getSelkeyForIM(name)
        // Keep LimeDB's own currentTableName in sync — getMappingByCode(softKeyboard:) uses it.
        db.setTableName(name)
        guard name != currentTableName else { return }
        currentTableName = name
        clearAllCaches()
        triggerPrefetch()
    }

    /// Backwards-compatible alias used by database setup.
    func setCurrentIM(tableName: String) { setTableName(tableName) }

    /// True if current table is a phonetic (tone-based) IM — enables code3r fallback.
    /// Note: Dayi is shape-based, not phonetic — excluded (L2 fix).
    var isPhoneticTable: Bool {
        currentTableName.hasPrefix("phonetic") || currentTableName.hasPrefix("eten") ||
        currentTableName.hasPrefix("hsu")
    }

    /// True if current table is Stroke5 / WB — enforces 5-character code limit (spec §5).
    var isWBTable: Bool {
        currentTableName == "wb" || currentTableName.hasPrefix("stroke")
    }

    // MARK: - Selkey / Keyname (spec §13)

    /// Returns the selection key string for the current IM (e.g. "1234567890").
    func getSelkey() -> String { cachedSelkey }

    /// Converts a typed code to display-friendly symbol names (e.g. "1q" → "ㄅㄆ").
    /// Delegates to LimeDB.keyToKeyName() which maintains per-table caches.
    func keyToKeyname(_ code: String) -> String {
        let converted = db.keyToKeyName(code, currentTableName, true)
        return converted.isEmpty ? code : converted
    }

    // MARK: - Real Code Length (spec §13 getRealCodeLength)

    /// Returns the code length consumed by the selected mapping in the composing buffer.
    /// For phonetic IMs, strips tone symbols [3467 space] to find the actual boundary.
    func getRealCodeLength(mapping: Mapping, composing: String) -> Int {
        let mappingCode = mapping.code
        guard composing.count > mappingCode.count else { return min(mappingCode.count, composing.count) }
        if isPhoneticTable {
            let toneChars: Set<Character> = ["3", "4", "6", "7", " "]
            // Stripped code length gives the base length without tone markers
            let stripped = mappingCode.filter { !toneChars.contains($0) }
            return max(stripped.count, 1)
        }
        return min(mappingCode.count, composing.count)
    }

    // MARK: - Core Search (spec §13 getMappingByCode)

    /// Returns mapping candidates for the given code.
    /// Prepends a COMPOSING_CODE echo record so index 0 is always the typed code.
    /// `isSoftKeyboard`: affects ordering (soft keyboard gets more results).
    /// `getAllRecords`: use a larger limit.
    func getMappingByCode(_ code: String, isSoftKeyboard: Bool = true,
                          getAllRecords: Bool = false, limit: Int = 50) -> [Mapping] {
        let effectiveLimit = getAllRecords ? 210 : limit

        if isPhoneticTable {
            // For phonetic IMs, delegate entirely to db.getMappingByCode(softKeyboard:getAllRecords:).
            // That method handles: preProcessingRemappingCode, tone detection, and between-search
            // (expandBetweenSearchClause). Doing the remap here too would double-remap for ETEN26/HSU.
            // Cache key uses the raw lowercased input (remap is deterministic, so this is stable).
            let cacheKey = "\(currentTableName):\(code.lowercased()):\(effectiveLimit)"
            cacheLock.lock()
            if blacklistCache.contains(cacheKey) { cacheLock.unlock(); return [] }
            if let cached = mappingCache[cacheKey] { cacheLock.unlock(); return cached }
            cacheLock.unlock()

            let dbResults = db.getMappingByCode(code, softKeyboard: isSoftKeyboard,
                                                getAllRecords: getAllRecords) ?? []
            let echo = Mapping(id: 0, code: code.lowercased(), word: code.lowercased(),
                               score: 0, baseScore: 0, recordType: Mapping.RecordType.composingCode)
            let list = dbResults.isEmpty ? [] : ([echo] + dbResults)
            cacheLock.lock()
            evictIfNeeded()
            if dbResults.isEmpty { blacklistCache.insert(cacheKey) }
            else                  { mappingCache[cacheKey] = list  }
            cacheLock.unlock()
            return list
        }

        // Non-phonetic path: delegate to db.getMappingByCode(softKeyboard:getAllRecords:),
        // which handles remap + between-search prefix expansion internally (H2 fix).
        let lowered = code.lowercased()
        let cacheKey = "\(currentTableName):\(lowered):\(effectiveLimit)"

        cacheLock.lock()
        if blacklistCache.contains(cacheKey) { cacheLock.unlock(); return [] }
        if let cached = mappingCache[cacheKey] { cacheLock.unlock(); return cached }
        cacheLock.unlock()

        var dbResults: [Mapping] = db.getMappingByCode(
            code, softKeyboard: isSoftKeyboard, getAllRecords: getAllRecords) ?? []

        // Apply sortSuggestions: false → DB insertion order (by id) instead of score order (spec §15)
        if !sortSuggestions {
            dbResults.sort { $0.id < $1.id }
        }

        // Prepend composing-code echo (spec §6 — index 0 always = typed code)
        let echo = Mapping(id: 0, code: code, word: code,
                           score: 0, baseScore: 0, recordType: Mapping.RecordType.composingCode)
        let list = dbResults.isEmpty ? [] : ([echo] + dbResults)

        cacheLock.lock()
        evictIfNeeded()
        if dbResults.isEmpty { blacklistCache.insert(cacheKey) }
        else                  { mappingCache[cacheKey] = list  }
        cacheLock.unlock()

        return list
    }

    // MARK: - Runtime Phrase Suggestion (spec §6, §13 makeRunTimeSuggestion)

    // Each entry is (committed Mapping, code it was typed with).
    // Mirrors Android's List<Pair<Mapping, String>> suggestionLoL.
    private var suggestionContext: [(mapping: Mapping, code: String)] = []
    private let suggestionLock = NSLock()

    /// Build incremental runtime phrase suggestions (spec §6 step 9).
    ///
    /// For each candidate in `currentList`, checks whether that candidate forms
    /// a valid phrase pair with any previously-committed word (via the `related` table).
    /// Matching candidates are promoted to just after the first real result.
    ///
    /// Called after `getMappingByCode()` on the background thread; gated by `smartChineseInput`.
    func makeRunTimeSuggestion(code: String, currentList: [Mapping]) -> [Mapping] {
        suggestionLock.lock()
        let context = suggestionContext
        suggestionLock.unlock()

        guard !context.isEmpty else { return currentList }

        // Build set of words that are valid follow-ons from any committed word.
        // Use the related cache (populated by getRelatedByWord) so it's fast.
        var validNext = Set<String>()
        for entry in context {
            let related = getRelatedByWord(entry.mapping.word)
            for r in related { validNext.insert(r.word) }
        }
        guard !validNext.isEmpty else { return currentList }

        // Partition currentList: promoted (in validNext) vs. the rest.
        // Preserve original order within each partition.
        var promoted: [Mapping] = []
        var rest:     [Mapping] = []
        for var m in currentList {
            if validNext.contains(m.word) {
                m.recordType = Mapping.RecordType.runtimeBuiltPhrase
                promoted.append(m)
            } else {
                rest.append(m)
            }
        }

        guard !promoted.isEmpty else { return currentList }

        // Insert promoted candidates right after the composing-echo (index 0),
        // keeping the rest in their original positions.
        if let echoIdx = rest.firstIndex(where: { $0.isComposingCodeRecord }) {
            rest.insert(contentsOf: promoted, at: echoIdx + 1)
            return rest
        }
        return promoted + rest
    }

    /// Record a committed candidate so future composing can be cross-checked (spec §6).
    func addToSuggestionContext(_ candidate: Mapping, code: String) {
        suggestionLock.lock()
        defer { suggestionLock.unlock() }
        suggestionContext.append((mapping: candidate, code: code))
        // Keep at most 4 entries to bound memory
        if suggestionContext.count > 4 { suggestionContext.removeFirst() }
    }

    /// Clear runtime suggestion context (spec §6 — on composing restart at length 1).
    func clearSuggestionContext() {
        suggestionLock.lock()
        suggestionContext = []
        suggestionLock.unlock()
    }

    // No pruneSuggestionOnBackspace: suggestionContext holds committed words, not composing
    // chains. Backspace shortens mComposing; makeRunTimeSuggestion reruns with the new code.

    // MARK: - Related Phrases (spec §13 getRelatedByWord)

    /// Returns related-phrase candidates following parentWord as Mapping objects.
    func getRelatedByWord(_ word: String, getAllRecords: Bool = false) -> [Mapping] {
        cacheLock.lock()
        if let cached = relatedCache[word] { cacheLock.unlock(); return cached }
        cacheLock.unlock()

        let limit = getAllRecords ? 50 : 10
        let results = (try? db.getRelatedMappings(parentWord: word, limit: limit)) ?? []

        cacheLock.lock()
        evictIfNeeded()
        relatedCache[word] = results
        cacheLock.unlock()

        return results
    }

    // MARK: - Learning (spec §9 learnRelatedPhraseAndUpdateScore)

    /// Records a committed candidate selection for score update and related-phrase learning.
    /// Matches spec §9: score learning + RP learning + LD trigger when RP score > 20.
    func learnRelatedPhraseAndUpdateScore(_ candidate: Mapping) {
        let parent = lastCommittedMapping
        lastCommittedMapping = candidate
        let tableName = currentTableName

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // Update score for the committed candidate.
            // H3 fix: increment by 1 (matches Java addScore/updateScoreCache),
            // fall back to candidate's own score (not a fabricated threshold constant).
            if candidate.id > 0 {
                let cacheKeyBase = "\(tableName):\(candidate.code.lowercased())"
                self.cacheLock.lock()
                let cached = self.mappingCache[cacheKeyBase]
                self.cacheLock.unlock()
                let currentScore = cached?.first(where: { $0.id == candidate.id })?.score
                    ?? candidate.score
                let newScore = currentScore + 1
                try? self.db.updateScore(id: candidate.id, score: newScore, tableName: tableName)
                // Invalidate cache for this code and similar prefix codes
                self.removeRemappedCodeCachedMappings(candidate.code.lowercased())
                self.updateSimilarCodeCache(candidate.code.lowercased())
            }

            // Learn related phrase from consecutive pair (spec §9 RP Learning)
            if let p = parent, !p.word.isEmpty, !candidate.word.isEmpty,
               p.isRealCandidate, candidate.isRealCandidate {
                let score = (try? self.db.learnRelatedPhrase(
                    parentWord: p.word, childWord: candidate.word)) ?? 0
                // Invalidate related cache
                self.cacheLock.lock()
                self.relatedCache.removeValue(forKey: p.word)
                self.cacheLock.unlock()
                // LD trigger: if RP score > 20 → feed into LD learning (spec §9)
                if score > 20 {
                    self.addLDPhrase(p, ending: false)
                    self.addLDPhrase(candidate, ending: true)
                }
            }
        }
    }

    // MARK: - LD Learning (spec §9 addLDPhrase / learnLDPhrase)

    /// Buffer a mapping for LD phrase learning. When ending=true, saves the accumulated list.
    func addLDPhrase(_ mapping: Mapping?, ending: Bool) {
        learnLock.lock()
        defer { learnLock.unlock() }
        if let m = mapping { ldPhraseList.append(m) }
        if ending {
            if ldPhraseList.count > 1 { ldPhraseListArray.append(ldPhraseList) }
            ldPhraseList = []
        }
    }

    /// Process accumulated LD phrases and write learned multi-character codes to DB.
    /// Called from KeyboardViewController on session end (postFinishInput equivalent, spec §9).
    func learnLDPhrase() {
        learnLock.lock()
        let toLearn = ldPhraseListArray
        ldPhraseListArray = []
        learnLock.unlock()

        let tableName = currentTableName
        for phrase in toLearn {
            guard phrase.count > 1, phrase.count <= 4 else { continue }
            var ldCode   = ""
            var qpCode   = ""
            var baseWord = ""
            for m in phrase {
                ldCode   += m.code
                if let first = m.code.first { qpCode += String(first) }
                baseWord += m.word
            }
            if isPhoneticTable {
                // Strip tone symbols (spec §9 QPCode / LDCode)
                let tones: Set<Character> = ["3", "4", "6", "7", " "]
                let stripped = ldCode.filter { !tones.contains($0) }
                if stripped.count > 1 {
                    try? db.addOrUpdateMappingRecord(code: stripped, word: baseWord, tableName: tableName)
                }
                if qpCode.count > 1 {
                    try? db.addOrUpdateMappingRecord(code: qpCode, word: baseWord, tableName: tableName)
                }
            } else {
                if ldCode.count > 1 {
                    try? db.addOrUpdateMappingRecord(code: ldCode, word: baseWord, tableName: tableName)
                }
            }
        }
    }

    // MARK: - Emoji (spec §6, §13 emojiConvert)

    /// Inject emoji candidates into a candidate list at the given position (spec §6 step 5).
    /// `type`: LimeDB.EMOJI_TW / EMOJI_CN / EMOJI_EN
    /// `insertAt`: 0-based index in the real (non-echo) candidate list.
    func injectEmoji(into list: [Mapping], code: String, type: Int, insertAt: Int = 3) -> [Mapping] {
        let emojiCandidates = db.emojiConvert(code, type)
        guard !emojiCandidates.isEmpty else { return list }

        // Deduplicate: drop emoji whose word is already in the list
        let existingWords = Set(list.map { $0.word })
        let unique = emojiCandidates.filter { !existingWords.contains($0.word) }
        guard !unique.isEmpty else { return list }

        var result = list
        let idx = min(insertAt, result.count)
        result.insert(contentsOf: unique, at: idx)
        return result
    }

    // MARK: - Reverse Lookup (spec §8, §13)

    /// Returns a formatted string of all codes for a given word, with key names applied.
    func getCodeListStringFromWord(_ word: String) -> String? {
        db.getCodeListStringByWord(word)
    }

    // MARK: - Finish Input (spec §13 postFinishInput)

    /// Flush all pending learning when the text field loses focus.
    func postFinishInput() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.learnLDPhrase()
        }
    }

    // MARK: - Cache Management

    func clearAllCaches() {
        cacheLock.lock()
        mappingCache.removeAll()
        relatedCache.removeAll()
        blacklistCache.removeAll()
        cacheLock.unlock()
    }

    private func evictIfNeeded() {
        // cacheLock must be held by caller
        if mappingCache.count >= maxCacheEntries  { mappingCache.removeAll() }
        if relatedCache.count  >= maxCacheEntries  { relatedCache.removeAll() }
        if blacklistCache.count >= maxCacheEntries  { blacklistCache.removeAll() }
    }

    // MARK: - Prefetch

    /// Background-thread prefetch for first-character keys — mirrors Android's prefetchCache().
    private func triggerPrefetch() {
        prefetchThread?.cancel()
        let snapshotTable = currentTableName
        let t = Thread { [weak self] in
            let keys = "abcdefghijklmnopqrstuvwxyz1234567890"
            for ch in keys {
                guard !Thread.current.isCancelled else { return }
                guard let self = self else { return }
                // Abort if the active table changed since prefetch started.
                guard self.currentTableName == snapshotTable else { return }
                _ = self.getMappingByCode(String(ch))
            }
        }
        t.qualityOfService = .background
        prefetchThread = t
        t.start()
    }

    // MARK: - Additional Cache / State Fields (mirrors Java scorelist, coderemapcache, etc.)

    private var scoreList: [Mapping] = []
    private var coderemap: [String: [String]] = [:]
    private var englishCache: [String: [Mapping]] = [:]
    private var emojiCache: [String: [Mapping]] = [:]
    private var keynameCache: [String: String] = [:]
    private var lastEnglishWord: String? = nil
    private var noSuggestionsForLastEnglishWord: Bool = false
    private var abandonPhraseSuggestion: Bool = false
    private var maxCodeLength: Int = 4
    private let scoreListLock = NSLock()

    // MARK: - Cache Initialisation (mirrors Java initialCache())

    /// Reinitialise all caches — mirrors Java SearchServer.initialCache().
    func initialCache() {
        scoreListLock.lock()
        scoreList.removeAll()
        scoreListLock.unlock()
        cacheLock.lock()
        mappingCache.removeAll()
        relatedCache.removeAll()
        blacklistCache.removeAll()
        cacheLock.unlock()
        coderemap.removeAll()
        englishCache.removeAll()
        emojiCache.removeAll()
        keynameCache.removeAll()
        clearSuggestionContext()
    }

    // MARK: - Clear (mirrors Java clear())

    /// Clear all runtime caches — mirrors Java SearchServer.clear().
    func clear() {
        scoreListLock.lock()
        scoreList.removeAll()
        scoreListLock.unlock()
        cacheLock.lock()
        mappingCache.removeAll()
        relatedCache.removeAll()
        blacklistCache.removeAll()
        cacheLock.unlock()
        englishCache.removeAll()
        emojiCache.removeAll()
        keynameCache.removeAll()
        coderemap.removeAll()
    }

    // MARK: - Longest Common Substring (mirrors Java lcs())

    /// Returns the longest common substring of two strings (recursive).
    func lcs(_ a: String, _ b: String) -> String {
        guard !a.isEmpty, !b.isEmpty else { return "" }
        if a.last == b.last {
            return lcs(String(a.dropLast()), String(b.dropLast())) + String(a.last!)
        }
        let x = lcs(a, String(b.dropLast()))
        let y = lcs(String(a.dropLast()), b)
        return x.count > y.count ? x : y
    }

    // MARK: - Cache Helpers (mirrors Java getMappingByCodeFromCacheOrDB / removeRemappedCodeCachedMappings / updateSimilarCodeCache)

    private func getMappingByCodeFromCacheOrDB(_ queryCode: String, getAllRecords: Bool) -> [Mapping] {
        // Cache key must match the format used by getMappingByCode (H7 fix):
        // "<table>:<lowercased-code>:<effectiveLimit>"
        let effectiveLimit = getAllRecords ? 210 : 50
        let key = "\(currentTableName):\(queryCode.lowercased()):\(effectiveLimit)"
        cacheLock.lock()
        if let cached = mappingCache[key] { cacheLock.unlock(); return cached }
        cacheLock.unlock()
        let results = db.getMappingByCode(queryCode, softKeyboard: true, getAllRecords: getAllRecords) ?? []
        cacheLock.lock()
        evictIfNeeded()
        if !results.isEmpty { mappingCache[key] = results }
        cacheLock.unlock()
        return results
    }

    /// Invalidates all cache entries that may hold mappings for `code`,
    /// regardless of whether they were stored under the raw-limit or all-records key (H7 fix).
    private func removeRemappedCodeCachedMappings(_ code: String) {
        let lowered = code.lowercased()
        let baseKey = "\(currentTableName):\(lowered)"
        let removeKey: (String) -> Void = { [weak self] key in
            guard let self = self else { return }
            self.mappingCache.removeValue(forKey: key)
            self.mappingCache.removeValue(forKey: "\(key):50")
            self.mappingCache.removeValue(forKey: "\(key):210")
        }
        cacheLock.lock()
        if let codelist = coderemap[baseKey] {
            for entry in codelist {
                removeKey("\(currentTableName):\(entry.lowercased())")
            }
        } else {
            removeKey(baseKey)
        }
        cacheLock.unlock()
    }

    private func updateSimilarCodeCache(_ code: String) {
        let len = min(code.count, 5)
        guard len > 1 else { return }
        for k in 1..<len {
            let key = String(code.prefix(code.count - k))
            let cacheKeyFull = "\(currentTableName):\(key.lowercased())"
            cacheLock.lock()
            if mappingCache[cacheKeyFull] != nil {
                mappingCache.removeValue(forKey: cacheKeyFull)
            }
            cacheLock.unlock()
            removeRemappedCodeCachedMappings(key)
        }
    }

    // MARK: - English Suggestions (mirrors Java getEnglishSuggestions())

    /// Returns English word suggestions for a given prefix, with caching.
    /// All shared-state reads/writes are protected by cacheLock (H6 fix).
    func getEnglishSuggestions(_ word: String) -> [Mapping] {
        cacheLock.lock()
        if word.count > 1, let last = lastEnglishWord,
           word.hasPrefix(last), noSuggestionsForLastEnglishWord {
            cacheLock.unlock()
            return []
        }
        if let cached = englishCache[word] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let strings = db.getEnglishSuggestions(word) ?? []
        let result = strings.map { s -> Mapping in
            var m = Mapping(id: 0, code: "", word: s, score: 0, baseScore: 0)
            m.recordType = Mapping.RecordType.englishSuggestion
            return m
        }

        cacheLock.lock()
        noSuggestionsForLastEnglishWord = result.isEmpty
        lastEnglishWord = word
        if !result.isEmpty { englishCache[word] = result }
        cacheLock.unlock()
        return result
    }

    // MARK: - Delegation Methods (UI components call SearchServer, not LimeDB directly)

    func getAllImKeyboardConfigList() -> [LimeImConfigRow] {
        return db.getImConfigList(nil, "keyboard")
    }

    func getImConfig(_ imCode: String, _ field: String) -> String {
        return db.getImConfig(imCode, field) ?? ""
    }

    @discardableResult
    func setImConfig(_ imCode: String, _ field: String, _ value: String) -> Bool {
        db.setImConfig(imCode, field, value)
        return true
    }

    func setIMKeyboard(_ im: String, _ value: String, _ keyboard: String) {
        db.setIMConfigKeyboard(im, value, keyboard)
    }

    func setIMKeyboard(_ imCode: String, _ keyboard: KeyboardConfig) {
        db.setImConfigKeyboard(imCode, keyboard)
    }

    func countRecordsByWordOrCode(_ table: String, _ curQuery: String?, searchByCode: Bool) -> Int {
        var whereParts: [String] = []
        var args: [String] = []
        if let q = curQuery, !q.isEmpty {
            if searchByCode {
                whereParts.append("code LIKE ?")
                args.append(q + "%")
            } else {
                whereParts.append("word LIKE ?")
                args.append("%" + q + "%")
            }
        }
        whereParts.append("ifnull(word, '') <> ''")
        let whereClause = whereParts.joined(separator: " AND ")
        return db.countRecords(table, whereClause, args.isEmpty ? nil : args)
    }

    func countRecords(_ table: String) -> Int {
        let where_ = table == "related"
            ? "ifnull(pword,'') <> '' AND ifnull(cword,'') <> ''"
            : "ifnull(word,'') <> ''"
        return db.countRecords(table, where_, nil)
    }

    func countRecordsRelated(_ pword: String?) -> Int {
        var whereParts: [String] = []
        var args: [String] = []
        var searchPword = pword
        var cwordFilter = ""
        if let p = pword, p.count > 1 {
            cwordFilter = String(p.dropFirst())
            searchPword = String(p.prefix(1))
        }
        if let p = searchPword, !p.isEmpty { whereParts.append("pword = ?"); args.append(p) }
        if !cwordFilter.isEmpty { whereParts.append("cword LIKE ?"); args.append(cwordFilter + "%") }
        whereParts.append("ifnull(cword,'') <> ''")
        return db.countRecords("related", whereParts.joined(separator: " AND "), args.isEmpty ? nil : args)
    }

    func hasRelated(_ pword: String?, _ cword: String?) -> Bool {
        guard let p = pword, !p.isEmpty else { return false }
        var whereParts = ["pword = ?"]
        var args = [p]
        if let c = cword, !c.isEmpty {
            whereParts.append("cword = ?")
            args.append(c)
        } else {
            whereParts.append("cword IS NULL")
        }
        return db.countRecords("related", whereParts.joined(separator: " AND "), args) > 0
    }

    func getRelatedByWord(_ pword: String?, maximum: Int, offset: Int) -> [Related] {
        return db.getRelated(pword, maximum, offset)
    }

    func getImAllConfigList(_ code: String?) -> [LimeImConfigRow] {
        return db.getImConfigList(code, nil)
    }

    func isValidTableName(_ tableName: String) -> Bool {
        return db.isValidTableName(tableName)
    }

    func getKeyboard() -> [KeyboardConfig] {
        return db.getKeyboardConfigList() ?? []
    }

    func getKeyboardConfig(_ keyboard: String) -> KeyboardConfig? {
        return db.getKeyboardConfig(keyboard)
    }

    func getKeyboardInfo(_ keyboardCode: String, _ field: String) -> String? {
        return db.getKeyboardInfo(keyboardCode, field)
    }

    func getRecords(_ code: String, _ query: String?, searchByCode: Bool,
                    _ maximum: Int, _ offset: Int) -> [LimeRecord] {
        return db.getRecordList(code, query, searchByCode: searchByCode, maximum, offset)
    }

    func getRecord(_ code: String, _ id: Int64) -> LimeRecord? {
        return db.getRecord(code, id)
    }

    @discardableResult
    func addRecord(_ table: String, _ values: [String: Any?]) -> Int64 {
        return db.addRecord(table, values)
    }

    @discardableResult
    func deleteRecord(_ table: String, _ whereClause: String?, _ whereArgs: [String]?) -> Int {
        return db.deleteRecord(table, whereClause, whereArgs)
    }

    @discardableResult
    func updateRecord(_ table: String, _ values: [String: Any?],
                      _ whereClause: String?, _ whereArgs: [String]?) -> Int {
        return db.updateRecord(table, values, whereClause, whereArgs)
    }

    func clearTable(_ table: String) {
        db.clearTable(table)
        clearAllCaches()
    }

    func resetCache() {
        db.resetCache()
        clearAllCaches()
    }

    func checkPhoneticKeyboardSetting() {
        db.checkPhoneticKeyboardSetting()
    }

    func checkBackupTable(_ table: String) -> Bool {
        return db.checkBackupTable(table)
    }

    func getBackupTableRecords(_ backupTableName: String) -> [[String: Any]]? {
        return db.getBackupTableRecords(backupTableName)
    }

    func removeImInfo(_ im: String, _ field: String) {
        db.removeImConfig(im, field)
    }

    func resetImConfig(_ imCode: String) {
        db.resetImConfig(imCode)
    }

    func restoredToDefault() {
        db.restoredToDefault()
    }

    func addOrUpdateMappingRecord(_ table: String, _ code: String, _ word: String, _ score: Int) {
        db.addOrUpdateMappingRecord(table, code, word, score)
    }

    func getKeyboardConfigList() -> [KeyboardConfig] {
        return db.getKeyboardConfigList() ?? []
    }

    // MARK: - Remaining delegation methods (mirrors Java SearchServer)

    func backupUserRecords(_ table: String) {
        db.backupUserRecords(table)
    }

    @discardableResult
    func restoreUserRecords(_ table: String) -> Int {
        return db.restoreUserRecords(table)
    }

    func getImConfigList(_ code: String?, _ configEntry: String?) -> [LimeImConfigRow] {
        return db.getImConfigList(code, configEntry)
    }

    func hanConvert(_ input: String, _ hanOption: Int) -> String {
        return db.hanConvert(input, hanOption)
    }

    func getTablename() -> String {
        return currentTableName
    }

    // MARK: - Test Hooks (internal — do not use in production code)
    internal var _testMappingCache:      [String: [Mapping]]                { mappingCache }
    internal var _testRelatedCache:      [String: [Mapping]]                { relatedCache }
    internal var _testBlacklistCache:    Set<String>                        { blacklistCache }
    internal var _testSuggestionContext: [(mapping: Mapping, code: String)] { suggestionContext }
}
