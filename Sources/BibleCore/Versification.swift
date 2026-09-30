import GRDB

/// The KJV ↔ Synodal numbering mapping table (FR-27, PRD 6.13).
/// KJV, Kralická and Ohienko share numbering, so "KJV" here means any of them.
///
/// The rules were checked against the texts of both translations in `bible.sqlite`:
/// - Psalms: numbered per the Septuagint (9–10 → 9, 11–113 → −1, 114–115 → 113, 116 → 114–115, 117–146 → −1,
///   147 → 146–147); superscriptions in the Synodal are separate verses 1–2, so the shift = the verse count difference.
///   For merged and split ones (9–10, 114–115, 116, 147) the shifts are explicit and checked against the text (Syn. 9:1 is a superscription);
/// - the rest are chapter boundaries and merged verses in Leviticus, Numbers, Joshua, 1 Samuel, Job, Proverbs,
///   Ecclesiastes, Song of Songs, Isaiah, Daniel, Hosea, Jonah, Acts, Romans, 2 Corinthians, 3 John.
/// Synodal verses without a counterpart (Septuagint additions, Ps 151, Dan 3:24–90, 13–14) give `nil`.
///
/// Other numbering systems (tech debt #25) bring a `VersificationTable` in the manifest; KJV is the hub,
/// so a verse between two non-KJV systems goes through KJV.
public struct Versification: Sendable {
    /// The mapping of one numbering system to KJV.
    struct Table: Sendable {
        var fromKJV: [VerseKey: VerseKey] = [:]
        var toKJV: [VerseKey: VerseKey] = [:]
        /// All KJV verses merged into one verse of this system (for user marks).
        var allKJV: [VerseKey: [VerseKey]] = [:]

        mutating func add(_ kjv: VerseKey, _ local: VerseKey) {
            fromKJV[kjv] = local
            if toKJV[local] == nil { toKJV[local] = kjv }
            allKJV[local, default: []].append(kjv)
        }

        /// Segments override the mapping; the remaining KJV verses are `identity` (the same number by default).
        init(segments: [Segment], kjvCounts: [Int: [Int: Int]],
             identity: (VerseKey, _ chapterCount: Int, _ chapters: [Int: Int]) -> VerseKey = { key, _, _ in key }) {
            var overridden = Set<VerseKey>()
            for segment in segments {
                for verse in segment.from...segment.to {
                    let kjv = VerseKey(book: segment.book, chapter: segment.chapter, verse: verse)
                    let target = segment.merge ? segment.localVerse : segment.localVerse + verse - segment.from
                    add(kjv, VerseKey(book: segment.book, chapter: segment.localChapter, verse: target))
                    overridden.insert(kjv)
                }
            }
            for (book, chapters) in kjvCounts {
                for (chapter, count) in chapters where count > 0 {
                    for verse in 1...count {
                        let kjv = VerseKey(book: book, chapter: chapter, verse: verse)
                        guard !overridden.contains(kjv) else { continue }
                        add(kjv, identity(kjv, count, chapters))
                    }
                }
            }
        }
    }

    private var tables: [Translation.Numbering: Table] = [:]

    /// A linear piece: verses `from...to` of a KJV chapter run consecutively from `localVerse` in chapter `localChapter`.
    /// `merge` means all these KJV verses form one verse of the other system.
    public struct Segment: Decodable, Hashable, Sendable {
        public let book: Int, chapter: Int, from: Int, to: Int
        public let localChapter: Int, localVerse: Int
        public var merge = false

        public init(book: Int, chapter: Int, from: Int, to: Int, localChapter: Int, localVerse: Int, merge: Bool = false) {
            self.book = book
            self.chapter = chapter
            self.from = from
            self.to = to
            self.localChapter = localChapter
            self.localVerse = localVerse
            self.merge = merge
        }

        enum CodingKeys: String, CodingKey { case book, chapter, from, to, localChapter, localVerse, merge }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(book: try c.decode(Int.self, forKey: .book), chapter: try c.decode(Int.self, forKey: .chapter),
                      from: try c.decode(Int.self, forKey: .from), to: try c.decode(Int.self, forKey: .to),
                      localChapter: try c.decode(Int.self, forKey: .localChapter),
                      localVerse: try c.decode(Int.self, forKey: .localVerse),
                      merge: try c.decodeIfPresent(Bool.self, forKey: .merge) ?? false)
        }
    }

    /// Synodal verses belonging to the previous KJV verse (the continuation of a split verse).
    struct Continuation { let synodal: VerseKey; let kjv: VerseKey }

    static let segments: [Segment] = [
        Segment(book: 3, chapter: 14, from: 55, to: 56, localChapter: 14, localVerse: 55, merge: true),
        Segment(book: 3, chapter: 14, from: 57, to: 57, localChapter: 14, localVerse: 56),
        Segment(book: 4, chapter: 12, from: 16, to: 16, localChapter: 13, localVerse: 1),
        Segment(book: 4, chapter: 13, from: 1, to: 33, localChapter: 13, localVerse: 2),
        Segment(book: 4, chapter: 29, from: 40, to: 40, localChapter: 30, localVerse: 1),
        Segment(book: 4, chapter: 30, from: 1, to: 16, localChapter: 30, localVerse: 2),
        Segment(book: 6, chapter: 6, from: 1, to: 1, localChapter: 5, localVerse: 16),
        Segment(book: 6, chapter: 6, from: 2, to: 27, localChapter: 6, localVerse: 1),
        Segment(book: 9, chapter: 23, from: 29, to: 29, localChapter: 24, localVerse: 1),
        Segment(book: 9, chapter: 24, from: 1, to: 22, localChapter: 24, localVerse: 2),
        Segment(book: 18, chapter: 40, from: 1, to: 5, localChapter: 39, localVerse: 31),
        Segment(book: 18, chapter: 40, from: 6, to: 24, localChapter: 40, localVerse: 1),
        Segment(book: 18, chapter: 41, from: 1, to: 8, localChapter: 40, localVerse: 20),
        Segment(book: 18, chapter: 41, from: 9, to: 34, localChapter: 41, localVerse: 1),
        Segment(book: 20, chapter: 13, from: 14, to: 25, localChapter: 13, localVerse: 15),
        Segment(book: 20, chapter: 18, from: 8, to: 24, localChapter: 18, localVerse: 9),
        Segment(book: 21, chapter: 5, from: 1, to: 1, localChapter: 4, localVerse: 17),
        Segment(book: 21, chapter: 5, from: 2, to: 20, localChapter: 5, localVerse: 1),
        // Song of Songs 1:1 (the title) is part of 1:1 in the Synodal.
        Segment(book: 22, chapter: 1, from: 1, to: 2, localChapter: 1, localVerse: 1, merge: true),
        Segment(book: 22, chapter: 1, from: 3, to: 17, localChapter: 1, localVerse: 2),
        Segment(book: 22, chapter: 6, from: 13, to: 13, localChapter: 7, localVerse: 1),
        Segment(book: 22, chapter: 7, from: 1, to: 13, localChapter: 7, localVerse: 2),
        Segment(book: 23, chapter: 3, from: 19, to: 20, localChapter: 3, localVerse: 19, merge: true),
        Segment(book: 23, chapter: 3, from: 21, to: 26, localChapter: 3, localVerse: 20),
        Segment(book: 27, chapter: 3, from: 24, to: 30, localChapter: 3, localVerse: 91),
        Segment(book: 27, chapter: 4, from: 1, to: 3, localChapter: 3, localVerse: 98),
        Segment(book: 27, chapter: 4, from: 4, to: 37, localChapter: 4, localVerse: 1),
        Segment(book: 28, chapter: 13, from: 16, to: 16, localChapter: 14, localVerse: 1),
        Segment(book: 28, chapter: 14, from: 1, to: 9, localChapter: 14, localVerse: 2),
        Segment(book: 32, chapter: 1, from: 17, to: 17, localChapter: 2, localVerse: 1),
        Segment(book: 32, chapter: 2, from: 1, to: 10, localChapter: 2, localVerse: 2),
        Segment(book: 44, chapter: 19, from: 40, to: 41, localChapter: 19, localVerse: 40, merge: true),
        Segment(book: 45, chapter: 16, from: 25, to: 27, localChapter: 14, localVerse: 24),
        Segment(book: 47, chapter: 11, from: 32, to: 33, localChapter: 11, localVerse: 32, merge: true),
        Segment(book: 47, chapter: 13, from: 12, to: 13, localChapter: 13, localVerse: 12, merge: true),
        Segment(book: 47, chapter: 13, from: 14, to: 14, localChapter: 13, localVerse: 13),
        // KJV Psalm 116:8–9 is one verse 114:8.
        Segment(book: 19, chapter: 116, from: 8, to: 9, localChapter: 114, localVerse: 8, merge: true),
        Segment(book: 19, chapter: 116, from: 10, to: 19, localChapter: 115, localVerse: 1),
    ]

    static let continuations: [Continuation] = [
        Continuation(synodal: VerseKey(book: 9, chapter: 20, verse: 43), kjv: VerseKey(book: 9, chapter: 20, verse: 42)),
        Continuation(synodal: VerseKey(book: 64, chapter: 1, verse: 15), kjv: VerseKey(book: 64, chapter: 1, verse: 14)),
    ]

    /// The Synodal chapter for a KJV psalm (except 116 and 147, which are split).
    static func synodalPsalm(_ chapter: Int) -> Int {
        switch chapter {
        case 10: 9
        case 11...113: chapter - 1
        case 115: 113
        case 117...146: chapter - 1
        default: chapter
        }
    }

    /// `counts[translation][book][chapter]` = verse count; `custom` are tables of new systems from the manifest.
    init(kjvCounts: [Int: [Int: Int]], synodalCounts: [Int: [Int: Int]],
         custom: [Translation.Numbering: VersificationTable] = [:]) {
        var synodal = Table(segments: Self.segments, kjvCounts: kjvCounts) { kjv, count, chapters in
            kjv.book == 19 ? Self.psalm(kjv, chapterCount: count, kjvCounts: chapters, synodalCounts: synodalCounts[19] ?? [:]) : kjv
        }
        // Psalm superscriptions (Synodal verses before the first counterpart) lead to the first KJV verse.
        for (chapter, count) in synodalCounts[19] ?? [:] where count > 0 {
            for verse in 1...count {
                let key = VerseKey(book: 19, chapter: chapter, verse: verse)
                if synodal.toKJV[key] != nil { break }
                let map = synodal.toKJV
                if let next = (verse...count).lazy.compactMap({ map[VerseKey(book: 19, chapter: chapter, verse: $0)] }).first {
                    synodal.toKJV[key] = next
                }
            }
        }
        for continuation in Self.continuations { synodal.toKJV[continuation.synodal] = continuation.kjv }
        tables[.synodal] = synodal
        for (numbering, table) in custom where !numbering.isBuiltIn {
            tables[numbering] = Table(segments: table.segments, kjvCounts: kjvCounts)
        }
    }

    /// A psalm: the chapter per the Septuagint, the shift = Synodal superscriptions (the verse count difference).
    private static func psalm(_ kjv: VerseKey, chapterCount: Int, kjvCounts: [Int: Int], synodalCounts: [Int: Int]) -> VerseKey {
        func key(_ chapter: Int, _ verse: Int) -> VerseKey { VerseKey(book: 19, chapter: chapter, verse: verse) }
        switch kjv.chapter {
        case 9: return key(9, kjv.verse + 1)                                   // superscription in 9
        case 10: return key(9, kjv.verse + (kjvCounts[9] ?? 0) + 1)            // 10 continues 9
        case 114: return key(113, kjv.verse)
        case 115: return key(113, kjv.verse + (kjvCounts[114] ?? 0))
        case 116: return key(114, kjv.verse)                                   // 1–7; 8–19 in segments
        case 147 where kjv.verse <= 11: return key(146, kjv.verse)
        case 147: return key(147, kjv.verse - 11)
        default:
            let chapter = synodalPsalm(kjv.chapter)
            let offset = max(0, (synodalCounts[chapter] ?? 0) - chapterCount)
            return key(chapter, kjv.verse + offset)
        }
    }

    public func synodal(fromKJV key: VerseKey) -> VerseKey? { tables[.synodal]?.fromKJV[key] }
    public func kjv(fromSynodal key: VerseKey) -> VerseKey? { tables[.synodal]?.toKJV[key] }

    /// All KJV verses that make up a Synodal verse, in KJV order.
    public func allKJV(fromSynodal key: VerseKey) -> [VerseKey] { allKJV(from: .synodal, key) }

    /// All KJV verses that make up a verse of the `numbering` system, in KJV order.
    public func allKJV(from numbering: Translation.Numbering, _ key: VerseKey) -> [VerseKey] {
        numbering == .kjv ? [key] : (tables[numbering]?.allKJV[key] ?? []).sorted()
    }

    /// The verse in another numbering system; `nil` means no counterpart (or no table for the system).
    public func map(_ key: VerseKey, fromNumbering source: Translation.Numbering, to target: Translation.Numbering) -> VerseKey? {
        if source == target { return key }
        let kjv = source == .kjv ? key : tables[source]?.toKJV[key]
        guard let kjv else { return nil }
        return target == .kjv ? kjv : tables[target]?.fromKJV[kjv]
    }

    /// The verse of another translation; `nil` means no counterpart.
    public func map(_ key: VerseKey, from source: Translation, to target: Translation) -> VerseKey? {
        map(key, fromNumbering: source.numbering, to: target.numbering)
    }

    public static func load(from repository: SQLiteBibleRepository) throws -> Versification {
        func counts(_ translation: Translation) throws -> [Int: [Int: Int]] {
            try repository.read { db in
                var result: [Int: [Int: Int]] = [:]
                for row in try Row.fetchAll(db, sql: "SELECT book, chapter, MAX(verse) AS n FROM verses WHERE translation = ? GROUP BY 1, 2",
                                            arguments: [translation.rawValue]) {
                    result[row["book"], default: [:]][row["chapter"]] = row["n"]
                }
                return result
            }
        }
        // The system's table comes from the first module that brings it.
        var custom: [Translation.Numbering: VersificationTable] = [:]
        for translation in Translation.allCases {
            if let table = translation.versificationTable, custom[translation.numbering] == nil {
                custom[translation.numbering] = table
            }
        }
        return Versification(kjvCounts: try counts(.kjv), synodalCounts: try counts(.synodal), custom: custom)
    }
}

/// The mapping table of a new numbering system to KJV (the manifest's `versification` field, tech debt #25):
/// only the differences from KJV; verses outside the segments keep the same number.
public struct VersificationTable: Decodable, Hashable, Sendable {
    public let segments: [Versification.Segment]

    public init(segments: [Versification.Segment]) {
        self.segments = segments
    }
}
