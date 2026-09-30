import Foundation
import Observation

/// Reader state for SwiftUI: translation, position, verses, search, database error.
@MainActor @Observable
public final class ReaderViewModel {
    public var translation: Translation = .kjv {
        didSet {
            guard translation != oldValue else { return }
            chapterPicker = nil
            if !keepLocationOnSwitch { remap(from: oldValue) }
            reload()
            savePosition()
            // The same query that produced the results, not the half-typed text in the field.
            if results != nil || searchError != nil { runSearch(submittedQuery) }
        }
    }
    public private(set) var location = Location(book: 1, chapter: 1)
    public private(set) var books: [Book] = []
    public private(set) var chapterCount = 0
    public private(set) var verses: [Verse] = [] {
        // Another chapter or translation: the previous comparison and illustrations are no longer about what is on screen.
        didSet { rebuildParallel(); comparison = nil; illustrations = nil }
    }
    /// The first selected verse (from `ChapterView`): switching translation opens exactly this one (FR-27).
    public var anchorVerse: Int?
    /// Esc in the Edit menu (FR-17): a counter, because the selection lives in `ChapterView`.
    public private(set) var clearSelectionRequest = 0

    /// Clear the verse selection; makes sense only when something is selected and there is no panel on the right for Esc to close.
    public var canClearSelection: Bool { anchorVerse != nil && illustrations == nil && comparison == nil }

    public func clearSelection() {
        clearSelectionRequest += 1
    }
    /// The second translation alongside (FR-26); `nil` means the parallel view is off.
    public var parallelTranslation: Translation? {
        didSet { if parallelTranslation != oldValue { rebuildParallel() } }
    }
    /// Parallel view rows: a verse of the main translation and the corresponding verses of the second.
    public private(set) var parallelRows: [ParallelRow] = []
    /// Numbering mapping tables (KJV is the hub); built on first need from the real database.
    @ObservationIgnored private lazy var versification: Versification? =
        (repository as? SQLiteBibleRepository).flatMap { try? Versification.load(from: $0) }
    @ObservationIgnored private var keepLocationOnSwitch = false
    /// The window with chapter numbers of the book clicked in the list (FR-37); `nil` means closed.
    public private(set) var chapterPicker: ChapterPicker?
    /// The verse to scroll to and highlight.
    public var focusedVerse: Int?
    /// Changes on every focus request, even if the verse number is the same
    /// (Ин 3:16 → Рим 3:16), so SwiftUI `onChange` fires.
    public private(set) var focusRequest = 0
    private var takenFocusRequest = 0
    public var query = ""
    /// `nil` when search is not active; an empty array means "Nothing found".
    /// Holds the loaded pages; `loadMore()` loads the rest (FR-20).
    public private(set) var results: [SearchResult]?
    /// The total match count in the scope, for the "Found: N" label.
    public private(set) var resultTotal = 0
    /// An error loading the next page: already loaded results stay on screen.
    public private(set) var pageError: String?
    /// Search scope (FR-19); changing it reruns the active search.
    public var searchScope: SearchScope = .bible {
        didSet {
            guard searchScope != oldValue else { return }
            if results != nil || searchError != nil { runSearch(submittedQuery) }
        }
    }
    public static let pageSize = 100
    /// The query that produced `results` (the search field may have changed since).
    public private(set) var submittedQuery = ""
    public private(set) var loadError: String?
    /// NFR-3: milliseconds from process start to the first shown chapter with verses (recorded by `ChapterView`).
    public private(set) var launchMilliseconds: Int?

    /// The first call with a non-empty chapter records the launch time; later ones are ignored.
    public func markFirstChapterShown(now: Date = Date()) {
        guard launchMilliseconds == nil, !verses.isEmpty else { return }
        launchMilliseconds = LaunchClock.millisecondsSinceStart(now: now)
    }
    /// A search error (not to be confused with "Nothing found").
    public private(set) var searchError: String?

    private let repository: BibleRepository?
    /// "Compare" mode instead of the chapter text (FR-36); `nil` means normal reading.
    public private(set) var comparison: Comparison?

    /// Compares the on-screen chapter with the chosen translations (the on-screen translation is the first column).
    /// Without a selection there is nothing to highlight, so the mode does not open.
    public func showComparison(of selectedVerses: Set<Int>, with chosen: [Translation]) {
        guard let repository, !selectedVerses.isEmpty, !verses.isEmpty else { return }
        let others = chosen.filter { $0 != translation }
        let columns = others.map { alignedVerses(of: $0, in: repository) }
        comparison = Comparison(location: location, translations: [translation] + others,
                                highlighted: selectedVerses,
                                rows: verses.indices.map { row in CompareRow(primary: verses[row], others: columns.map { $0[row] }) })
    }

    public func closeComparison() {
        comparison = nil
    }

    @ObservationIgnored private let positionStore: KeyValueStore?

    /// The last reading position (FR-25): translation, book, chapter.
    struct Position: Codable {
        let translation: Translation
        let book: Int
        let chapter: Int
    }

    public static let positionKey = "lastPosition"

    /// `positionStore` keeps the last position; without it the app opens at Genesis 1.
    public init(positionStore: KeyValueStore? = nil, openRepository: () throws -> BibleRepository) {
        self.positionStore = positionStore
        do {
            repository = try openRepository()
        } catch {
            repository = nil
            loadError = "\(error)"
            return
        }
        if let data = positionStore?.data(forKey: Self.positionKey),
           let position = try? JSONDecoder().decode(Position.self, from: data),
           Book(number: position.book) != nil, position.chapter > 0 {
            // Assignment in init does not trigger didSet; `reload` clamps a chapter outside the book.
            translation = position.translation
            location = Location(book: position.book, chapter: position.chapter)
        }
        reload()
        // `reload` may have clamped the chapter, so save the now valid position.
        if positionStore != nil { savePosition() }
    }

    private func savePosition() {
        guard let positionStore else { return }
        let position = Position(translation: translation, book: location.book, chapter: location.chapter)
        guard let data = try? JSONEncoder().encode(position) else { return }
        positionStore.set(data, forKey: Self.positionKey)
    }

    /// Neighboring chapters are computed when a chapter loads, not on every toolbar render.
    public private(set) var canGoPrevious = false
    public private(set) var canGoNext = false

    /// ◀ ▶ close search results, like choosing a chapter.
    public func goPrevious() {
        if let target = navigator.previous(from: location) { closeSearch(); open(target) }
    }

    public func goNext() {
        if let target = navigator.next(from: location) { closeSearch(); open(target) }
    }

    private func closeSearch() {
        results = nil
        searchError = nil
    }

    public func open(_ target: Location, focus verse: Int? = nil) {
        chapterPicker = nil
        location = target
        focusedVerse = verse
        if verse != nil { focusRequest += 1 }
        reload()
        savePosition()
    }

    /// A click on a book: shows its chapters over the text, the current chapter stays open (FR-37).
    public func pickBook(_ book: Int, from origin: ChapterPicker.Origin = .sidebar) {
        guard let count = try? repository?.chapterCount(book: book, translation: translation), count > 0 else {
            chapterPicker = nil
            return
        }
        chapterPicker = ChapterPicker(book: book, chapterCount: count,
                                      current: book == location.book ? location.chapter : nil, origin: origin)
    }

    /// A click on the chapter title in the toolbar: the open book's chapters below the title.
    public func pickCurrentBook() {
        pickBook(location.book, from: .title)
    }

    /// A click on a chapter number in the window: opens the chapter and closes the window and search results.
    public func pickChapter(_ chapter: Int) {
        guard let picker = chapterPicker else { return }
        chapterPicker = nil
        closeSearch()
        open(Location(book: picker.book, chapter: chapter))
    }

    /// The database is open and only a read failed: "Try again" makes sense.
    public var canRetryLoad: Bool { repository != nil && loadError != nil }

    public func retryLoad() {
        reload()
    }

    public func dismissChapterPicker() {
        chapterPicker = nil
    }

    /// Opens the verse a note was found for and closes the results.
    public func openNote(_ key: VerseKey) {
        results = nil
        openCanonical(book: key.book, chapter: key.chapter, verse: key.verse)
    }

    // MARK: KJV numbering for user data (tech debt #24)

    /// The key of a current-chapter verse in KJV numbering: notes, highlights and bookmarks are stored this way,
    /// so in the Synodal they sit on the same content. A verse without a counterpart uses its own number.
    public func canonicalKey(_ verse: Int) -> VerseKey {
        let key = VerseKey(book: location.book, chapter: location.chapter, verse: verse)
        return mapped(key, from: translation, to: .kjv) ?? key
    }

    /// All KJV keys of a current-chapter verse: a merged Synodal verse shows the marks of all its parts.
    public func canonicalKeys(_ verse: Int) -> [VerseKey] {
        let key = VerseKey(book: location.book, chapter: location.chapter, verse: verse)
        guard !translation.sharesKJVNumbering, let all = versification?.allKJV(from: translation.numbering, key), !all.isEmpty
        else { return [canonicalKey(verse)] }
        return all
    }

    /// A bookmark on the current chapter in KJV numbering: the KJV chapter where most verses land
    /// (Synodal Num 13 starts with KJV 12:16, but it is Num 13).
    public var canonicalChapter: Bookmark.Target {
        let chapters = verses.map { canonicalKey($0.verse) }
        let counts = Dictionary(chapters.map { ($0.chapter, 1) }, uniquingKeysWith: +)
        let chapter = counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key ?? location.chapter
        return Bookmark.Target(book: location.book, chapter: chapter, verse: nil)
    }

    /// A position stored in KJV numbering, in the current translation's numbering.
    public func localReference(book: Int, chapter: Int, verse: Int?) -> Reference {
        let key = VerseKey(book: book, chapter: chapter, verse: verse ?? 1)
        let target = mapped(key, from: .kjv, to: translation) ?? key
        return Reference(book: target.book, chapter: target.chapter, verseStart: verse == nil ? nil : target.verse)
    }

    /// Opens a position stored in KJV numbering.
    public func openCanonical(book: Int, chapter: Int, verse: Int?) {
        let reference = localReference(book: book, chapter: chapter, verse: verse)
        open(Location(book: reference.book, chapter: reference.chapter), focus: reference.verseStart)
    }

    /// Opens a verse and closes the result list.
    public func open(_ result: SearchResult) {
        results = nil
        open(Location(book: result.verse.book, chapter: result.verse.chapter), focus: result.verse.verse)
    }

    /// A reference leads to the passage, otherwise full-text search in the active translation.
    public func submitSearch() {
        guard let repository else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            results = nil
            searchError = nil
        } else if let reference = Reference.parse(text) {
            results = nil
            searchError = nil
            open(Location(book: reference.book, chapter: reference.chapter), focus: reference.verseStart)
        } else {
            runSearch(text)
        }
    }

    /// The "current book" scope for the bar above the results; if already searching in a book, that one.
    public var currentBookScope: SearchScope {
        if case .book = searchScope { return searchScope }
        return .book(location.book)
    }

    public var canLoadMore: Bool {
        guard let results else { return false }
        return results.count < resultTotal
    }

    /// The next page of results (scrolling to the end of the list).
    public func loadMore() {
        guard let repository, let loaded = results, canLoadMore else { return }
        do {
            let page = try repository.searchPage(submittedQuery, translation: translation, scope: searchScope,
                                                 offset: loaded.count, limit: Self.pageSize)
            results = loaded + page.results
            // A short page is the end of the list, even if the counter promised more: otherwise the indicator would spin forever.
            resultTotal = page.results.count < Self.pageSize ? loaded.count + page.results.count : page.total
            pageError = nil
        } catch {
            pageError = "\(error)"
        }
    }

    private func runSearch(_ text: String) {
        guard let repository else { return }
        submittedQuery = text
        do {
            let page = try repository.searchPage(text, translation: translation, scope: searchScope, offset: 0, limit: Self.pageSize)
            results = page.results
            resultTotal = page.total
            searchError = nil
            pageError = nil
        } catch {
            results = nil
            resultTotal = 0
            searchError = "\(error)"
        }
    }

    /// The verse to focus, once per request: redisplaying the chapter
    /// (after clearing search) does not steal focus from the search field.
    public func takeFocus() -> Int? {
        guard focusRequest != takenFocusRequest, let focusedVerse else { return nil }
        takenFocusRequest = focusRequest
        return focusedVerse
    }

    /// The illustrations panel to the right of the text (FR-33); `nil` means closed. A new request replaces the previous one.
    public private(set) var illustrations: IllustrationRequest?

    /// Opens the illustrations panel for the selected verses; if there is nothing to search, the panel does not change.
    public func showIllustrations(for selectedVerses: Set<Int>) {
        if let request = illustrationRequest(for: selectedVerses) { illustrations = request }
    }

    public func closeIllustrations() {
        illustrations = nil
    }

    /// An illustrations request (FR-33): the reference in the screen language and the text of the same verses in KJV, for English search.
    /// A verse without a KJV counterpart (Septuagint additions) is skipped; with none at all, `nil`.
    public func illustrationRequest(for selectedVerses: Set<Int>) -> IllustrationRequest? {
        let chosen = verses.filter { selectedVerses.contains($0.verse) }
        guard let repository, !chosen.isEmpty else { return nil }
        let keys = chosen.flatMap { canonicalKeys($0.verse) }
        var texts: [String] = []
        for chapter in Set(keys.map(\.chapter)).sorted() {
            let wanted = Set(keys.filter { $0.chapter == chapter }.map(\.verse))
            guard let kjv = try? repository.verses(book: location.book, chapter: chapter, translation: .kjv) else { continue }
            texts += kjv.filter { wanted.contains($0.verse) }.map(\.text)
        }
        guard !texts.isEmpty else { return nil }
        // `location` is always within the canon (`open` and `reload` clamp it).
        let book = Book.all[location.book - 1].name(in: translation)
        let reference = "\(book) \(location.chapter):\(Quote.verseList(chosen.map(\.verse)))"
        return IllustrationRequest(reference: reference, kjvText: texts, language: translation.language.code)
    }

    /// The text of a draft passage (KJV numbering) in the on-screen translation: the tooltip of a live reference (FR-38).
    public func text(of reference: Reference) -> String? {
        guard let repository, let start = reference.verseStart else { return nil }
        let first = localReference(book: reference.book, chapter: reference.chapter, verse: start)
        let last = localReference(book: reference.book, chapter: reference.chapter, verse: reference.verseEnd ?? start)
        // `localReference` with a verse always returns a verse.
        let from = first.verseStart!
        guard let verses = try? repository.verses(book: first.book, chapter: first.chapter, translation: translation)
        else { return nil }
        // A range that runs into the next chapter of another numbering goes to the end of the chapter.
        let to = last.chapter == first.chapter ? last.verseStart! : Int.max
        let texts = verses.filter { (from...max(from, to)).contains($0.verse) }.map(\.text)
        return texts.isEmpty ? nil : texts.joined(separator: " ")
    }

    /// The quote of the selected verses for "To draft": the same as copying (FR-38).
    public func quote(for selectedVerses: Set<Int>) -> String? {
        Quote.format(verses.filter { selectedVerses.contains($0.verse) })
    }

    private var navigator: Navigator {
        Navigator { [repository, translation] book in
            (try? repository?.chapterCount(book: book, translation: translation)) ?? 0
        }
    }

    /// The verse with the same content in another numbering; without a selection, the chapter of the first verse.
    private func remap(from old: Translation) {
        let verse = anchorVerse ?? 1
        // A verse without a counterpart (Septuagint additions) maps to the nearest previous one that has it.
        var found: VerseKey?
        for candidate in stride(from: verse, through: 1, by: -1) {
            found = mapped(VerseKey(book: location.book, chapter: location.chapter, verse: candidate), from: old, to: translation)
            if found != nil { break }
        }
        guard let target = found else { return }
        location = Location(book: target.book, chapter: target.chapter)
        if anchorVerse != nil {
            focusedVerse = target.verse
            focusRequest += 1
        }
        anchorVerse = nil
    }

    private func mapped(_ key: VerseKey, from source: Translation, to target: Translation) -> VerseKey? {
        if source.numbering == target.numbering { return key }
        return versification?.map(key, from: source, to: target)
    }

    /// Verses of the second translation are laid out over the main one's rows: each goes next to the verse it
    /// maps back to; a verse without a counterpart (Septuagint additions) goes next to the previous one.
    private func rebuildParallel() {
        guard let other = parallelTranslation, other != translation, let repository, !verses.isEmpty else {
            parallelRows = []
            return
        }
        parallelRows = zip(verses, alignedVerses(of: other, in: repository)).map { ParallelRow(primary: $0, secondary: $1) }
    }

    /// Another translation's verses over the rows of the on-screen chapter (FR-26, FR-36).
    private func alignedVerses(of other: Translation, in repository: BibleRepository) -> [[Verse]] {
        var secondary: [[Verse]] = Array(repeating: [], count: verses.count)
        let book = location.book
        let chapter = location.chapter
        let targets = verses.compactMap { mapped(VerseKey(book: book, chapter: chapter, verse: $0.verse), from: translation, to: other) }
        let chapters = Set(targets.map(\.chapter)).sorted()
        let rowOf = Dictionary(uniqueKeysWithValues: verses.enumerated().map { ($1.verse, $0) })
        var lastRow: Int?
        for secondChapter in chapters {
            let others = (try? repository.verses(book: book, chapter: secondChapter, translation: other)) ?? []
            for verse in others {
                let back = mapped(VerseKey(book: book, chapter: secondChapter, verse: verse.verse), from: other, to: translation)
                if let back {
                    guard back.chapter == chapter, let row = rowOf[back.verse] else { continue }
                    secondary[row].append(verse)
                    lastRow = row
                } else if let lastRow {
                    secondary[lastRow].append(verse)
                }
            }
        }
        return secondary
    }

    private func reload() {
        guard let repository else { return }
        do {
            books = try repository.books(translation: translation)
            chapterCount = try repository.chapterCount(book: location.book, translation: translation)
            if chapterCount > 0, location.chapter > chapterCount {
                location = Location(book: location.book, chapter: chapterCount)
            }
            verses = try repository.verses(book: location.book, chapter: location.chapter, translation: translation)
            // A one-off read error does not leave the error screen forever (tech debt #11).
            loadError = nil
            let navigator = navigator
            canGoPrevious = navigator.previous(from: location) != nil
            canGoNext = navigator.next(from: location) != nil
        } catch {
            loadError = "\(error)"
        }
    }
}

/// A parallel view row (FR-26).
public struct ParallelRow: Identifiable, Sendable {
    public let primary: Verse
    public let secondary: [Verse]
    public var id: Int { primary.verse }
}

/// The chapter picker contents: the book, its chapter count and the current chapter if this is the open book.
public struct ChapterPicker: Equatable, Sendable {
    public let book: Int
    public let chapterCount: Int
    public let current: Int?
    /// Where it was opened from: a book in the sidebar or the chapter title in the toolbar.
    public let origin: Origin
    public enum Origin: Sendable { case sidebar, title }
    /// Grid columns: the ↑ ↓ arrows move by a row, that is by this many chapters.
    public static let columns = 10

    public init(book: Int, chapterCount: Int, current: Int?, origin: Origin = .sidebar) {
        self.book = book
        self.chapterCount = chapterCount
        self.current = current
        self.origin = origin
    }

    /// The chapter under the keyboard cursor when the window opened: the current one or the first.
    public var initialCursor: Int { current ?? 1 }

    /// The cursor after an arrow; it does not leave the book.
    public func move(_ cursor: Int, by delta: Int) -> Int {
        min(max(cursor + delta, 1), chapterCount)
    }
}
