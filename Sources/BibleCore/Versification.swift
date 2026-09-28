import GRDB

/// Таблиця відповідностей нумерації KJV ↔ Синодальний (FR-27, PRD 6.13).
/// KJV, Kralická й Огієнко нумеровані однаково, тож «KJV» тут — будь-який із них.
///
/// Правила звірено з текстами обох перекладів у `bible.sqlite`:
/// - Псалми: номер за Септуагінтою (9–10 → 9, 11–113 → −1, 114–115 → 113, 116 → 114–115, 117–146 → −1,
///   147 → 146–147); надписи в Синодальному — окремі вірші 1–2, тож зсув = різниця кількості віршів.
///   Для злитих і розділених (9–10, 114–115, 116, 147) зсуви задано явно й звірено з текстом (Син. 9:1 — надпис);
/// - решта — межі розділів і злиті вірші в Левит, Числа, Ісус Навин, 1 Самуїла, Йов, Приповісті,
///   Екклезіаст, Пісня пісень, Ісая, Даниїл, Осія, Йона, Дії, Римлян, 2 Коринтян, 3 Івана.
/// Вірші Синодального без відповідника (доповнення Септуагінти, Пс 151, Дан 3:24–90, 13–14) дають `nil`.
///
/// Інші системи нумерації (tech debt #25) приносять `VersificationTable` у маніфесті; KJV — вузол,
/// тож вірш між двома не-KJV системами йде через KJV.
public struct Versification: Sendable {
    /// Відповідності однієї системи нумерації до KJV.
    struct Table: Sendable {
        var fromKJV: [VerseKey: VerseKey] = [:]
        var toKJV: [VerseKey: VerseKey] = [:]
        /// Усі вірші KJV, що злиті в один вірш цієї системи (для позначок користувача).
        var allKJV: [VerseKey: [VerseKey]] = [:]

        mutating func add(_ kjv: VerseKey, _ local: VerseKey) {
            fromKJV[kjv] = local
            if toKJV[local] == nil { toKJV[local] = kjv }
            allKJV[local, default: []].append(kjv)
        }

        /// Сегменти перекривають відповідність; решта віршів KJV — `identity` (за замовчуванням той самий номер).
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

    /// Лінійний шматок: вірші `from...to` розділу KJV ідуть підряд від `localVerse` у розділі `localChapter`.
    /// `merge` — усі ці вірші KJV складають один вірш іншої системи.
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

    /// Вірші Синодального, що належать до попереднього вірша KJV (продовження розділеного вірша).
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
        // Пісня пісень 1:1 (заголовок) у Синодальному входить у 1:1.
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
        // Псалом 116:8–9 KJV — один вірш 114:8.
        Segment(book: 19, chapter: 116, from: 8, to: 9, localChapter: 114, localVerse: 8, merge: true),
        Segment(book: 19, chapter: 116, from: 10, to: 19, localChapter: 115, localVerse: 1),
    ]

    static let continuations: [Continuation] = [
        Continuation(synodal: VerseKey(book: 9, chapter: 20, verse: 43), kjv: VerseKey(book: 9, chapter: 20, verse: 42)),
        Continuation(synodal: VerseKey(book: 64, chapter: 1, verse: 15), kjv: VerseKey(book: 64, chapter: 1, verse: 14)),
    ]

    /// Розділ Синодального для псалма KJV (без 116 і 147, які діляться).
    static func synodalPsalm(_ chapter: Int) -> Int {
        switch chapter {
        case 10: 9
        case 11...113: chapter - 1
        case 115: 113
        case 117...146: chapter - 1
        default: chapter
        }
    }

    /// `counts[translation][book][chapter]` = кількість віршів; `custom` — таблиці нових систем з маніфесту.
    init(kjvCounts: [Int: [Int: Int]], synodalCounts: [Int: [Int: Int]],
         custom: [Translation.Numbering: VersificationTable] = [:]) {
        var synodal = Table(segments: Self.segments, kjvCounts: kjvCounts) { kjv, count, chapters in
            kjv.book == 19 ? Self.psalm(kjv, chapterCount: count, kjvCounts: chapters, synodalCounts: synodalCounts[19] ?? [:]) : kjv
        }
        // Надписи псалмів (вірші Синодального перед першим відповідником) ведуть до першого вірша KJV.
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

    /// Псалом: розділ за Септуагінтою, зсув = надписи Синодального (різниця кількості віршів).
    private static func psalm(_ kjv: VerseKey, chapterCount: Int, kjvCounts: [Int: Int], synodalCounts: [Int: Int]) -> VerseKey {
        func key(_ chapter: Int, _ verse: Int) -> VerseKey { VerseKey(book: 19, chapter: chapter, verse: verse) }
        switch kjv.chapter {
        case 9: return key(9, kjv.verse + 1)                                   // надпис у 9
        case 10: return key(9, kjv.verse + (kjvCounts[9] ?? 0) + 1)            // 10 продовжує 9
        case 114: return key(113, kjv.verse)
        case 115: return key(113, kjv.verse + (kjvCounts[114] ?? 0))
        case 116: return key(114, kjv.verse)                                   // 1–7; 8–19 у сегментах
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

    /// Усі вірші KJV, з яких складається вірш Синодального, у порядку KJV.
    public func allKJV(fromSynodal key: VerseKey) -> [VerseKey] { allKJV(from: .synodal, key) }

    /// Усі вірші KJV, з яких складається вірш системи `numbering`, у порядку KJV.
    public func allKJV(from numbering: Translation.Numbering, _ key: VerseKey) -> [VerseKey] {
        numbering == .kjv ? [key] : (tables[numbering]?.allKJV[key] ?? []).sorted()
    }

    /// Вірш в іншій системі нумерації; `nil` — відповідника немає (або немає таблиці системи).
    public func map(_ key: VerseKey, fromNumbering source: Translation.Numbering, to target: Translation.Numbering) -> VerseKey? {
        if source == target { return key }
        let kjv = source == .kjv ? key : tables[source]?.toKJV[key]
        guard let kjv else { return nil }
        return target == .kjv ? kjv : tables[target]?.fromKJV[kjv]
    }

    /// Вірш іншого перекладу; `nil` — відповідника немає.
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
        // Таблиця системи — з першого модуля, що її приносить.
        var custom: [Translation.Numbering: VersificationTable] = [:]
        for translation in Translation.allCases {
            if let table = translation.versificationTable, custom[translation.numbering] == nil {
                custom[translation.numbering] = table
            }
        }
        return Versification(kjvCounts: try counts(.kjv), synodalCounts: try counts(.synodal), custom: custom)
    }
}

/// Таблиця відповідностей нової системи нумерації до KJV (поле `versification` маніфесту, tech debt #25):
/// лише відмінності від KJV; вірші поза сегментами мають той самий номер.
public struct VersificationTable: Decodable, Hashable, Sendable {
    public let segments: [Versification.Segment]

    public init(segments: [Versification.Segment]) {
        self.segments = segments
    }
}
