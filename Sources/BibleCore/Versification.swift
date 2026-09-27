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
public struct Versification: Sendable {
    private var toSynodal: [VerseKey: VerseKey] = [:]
    private var toKJV: [VerseKey: VerseKey] = [:]
    /// Усі вірші KJV, що злиті в один вірш Синодального (для позначок користувача).
    private var allKJV: [VerseKey: [VerseKey]] = [:]

    /// Лінійний шматок: вірші `from...to` розділу KJV ідуть підряд від `synodalVerse` у розділі `synodalChapter`.
    /// `merge` — усі ці вірші KJV складають один вірш Синодального.
    struct Segment {
        let book: Int, chapter: Int, from: Int, to: Int
        let synodalChapter: Int, synodalVerse: Int
        var merge = false
    }

    /// Вірші Синодального, що належать до попереднього вірша KJV (продовження розділеного вірша).
    struct Continuation { let synodal: VerseKey; let kjv: VerseKey }

    static let segments: [Segment] = [
        Segment(book: 3, chapter: 14, from: 55, to: 56, synodalChapter: 14, synodalVerse: 55, merge: true),
        Segment(book: 3, chapter: 14, from: 57, to: 57, synodalChapter: 14, synodalVerse: 56),
        Segment(book: 4, chapter: 12, from: 16, to: 16, synodalChapter: 13, synodalVerse: 1),
        Segment(book: 4, chapter: 13, from: 1, to: 33, synodalChapter: 13, synodalVerse: 2),
        Segment(book: 4, chapter: 29, from: 40, to: 40, synodalChapter: 30, synodalVerse: 1),
        Segment(book: 4, chapter: 30, from: 1, to: 16, synodalChapter: 30, synodalVerse: 2),
        Segment(book: 6, chapter: 6, from: 1, to: 1, synodalChapter: 5, synodalVerse: 16),
        Segment(book: 6, chapter: 6, from: 2, to: 27, synodalChapter: 6, synodalVerse: 1),
        Segment(book: 9, chapter: 23, from: 29, to: 29, synodalChapter: 24, synodalVerse: 1),
        Segment(book: 9, chapter: 24, from: 1, to: 22, synodalChapter: 24, synodalVerse: 2),
        Segment(book: 18, chapter: 40, from: 1, to: 5, synodalChapter: 39, synodalVerse: 31),
        Segment(book: 18, chapter: 40, from: 6, to: 24, synodalChapter: 40, synodalVerse: 1),
        Segment(book: 18, chapter: 41, from: 1, to: 8, synodalChapter: 40, synodalVerse: 20),
        Segment(book: 18, chapter: 41, from: 9, to: 34, synodalChapter: 41, synodalVerse: 1),
        Segment(book: 20, chapter: 13, from: 14, to: 25, synodalChapter: 13, synodalVerse: 15),
        Segment(book: 20, chapter: 18, from: 8, to: 24, synodalChapter: 18, synodalVerse: 9),
        Segment(book: 21, chapter: 5, from: 1, to: 1, synodalChapter: 4, synodalVerse: 17),
        Segment(book: 21, chapter: 5, from: 2, to: 20, synodalChapter: 5, synodalVerse: 1),
        // Пісня пісень 1:1 (заголовок) у Синодальному входить у 1:1.
        Segment(book: 22, chapter: 1, from: 1, to: 2, synodalChapter: 1, synodalVerse: 1, merge: true),
        Segment(book: 22, chapter: 1, from: 3, to: 17, synodalChapter: 1, synodalVerse: 2),
        Segment(book: 22, chapter: 6, from: 13, to: 13, synodalChapter: 7, synodalVerse: 1),
        Segment(book: 22, chapter: 7, from: 1, to: 13, synodalChapter: 7, synodalVerse: 2),
        Segment(book: 23, chapter: 3, from: 19, to: 20, synodalChapter: 3, synodalVerse: 19, merge: true),
        Segment(book: 23, chapter: 3, from: 21, to: 26, synodalChapter: 3, synodalVerse: 20),
        Segment(book: 27, chapter: 3, from: 24, to: 30, synodalChapter: 3, synodalVerse: 91),
        Segment(book: 27, chapter: 4, from: 1, to: 3, synodalChapter: 3, synodalVerse: 98),
        Segment(book: 27, chapter: 4, from: 4, to: 37, synodalChapter: 4, synodalVerse: 1),
        Segment(book: 28, chapter: 13, from: 16, to: 16, synodalChapter: 14, synodalVerse: 1),
        Segment(book: 28, chapter: 14, from: 1, to: 9, synodalChapter: 14, synodalVerse: 2),
        Segment(book: 32, chapter: 1, from: 17, to: 17, synodalChapter: 2, synodalVerse: 1),
        Segment(book: 32, chapter: 2, from: 1, to: 10, synodalChapter: 2, synodalVerse: 2),
        Segment(book: 44, chapter: 19, from: 40, to: 41, synodalChapter: 19, synodalVerse: 40, merge: true),
        Segment(book: 45, chapter: 16, from: 25, to: 27, synodalChapter: 14, synodalVerse: 24),
        Segment(book: 47, chapter: 11, from: 32, to: 33, synodalChapter: 11, synodalVerse: 32, merge: true),
        Segment(book: 47, chapter: 13, from: 12, to: 13, synodalChapter: 13, synodalVerse: 12, merge: true),
        Segment(book: 47, chapter: 13, from: 14, to: 14, synodalChapter: 13, synodalVerse: 13),
        // Псалом 116:8–9 KJV — один вірш 114:8.
        Segment(book: 19, chapter: 116, from: 8, to: 9, synodalChapter: 114, synodalVerse: 8, merge: true),
        Segment(book: 19, chapter: 116, from: 10, to: 19, synodalChapter: 115, synodalVerse: 1),
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

    /// `counts[translation][book][chapter]` = кількість віршів.
    init(kjvCounts: [Int: [Int: Int]], synodalCounts: [Int: [Int: Int]]) {
        var overridden = Set<VerseKey>()
        func add(_ kjv: VerseKey, _ synodal: VerseKey) {
            toSynodal[kjv] = synodal
            if toKJV[synodal] == nil { toKJV[synodal] = kjv }
            allKJV[synodal, default: []].append(kjv)
        }
        for segment in Self.segments {
            for verse in segment.from...segment.to {
                let kjv = VerseKey(book: segment.book, chapter: segment.chapter, verse: verse)
                let target = segment.merge ? segment.synodalVerse : segment.synodalVerse + verse - segment.from
                add(kjv, VerseKey(book: segment.book, chapter: segment.synodalChapter, verse: target))
                overridden.insert(kjv)
            }
        }
        for (book, chapters) in kjvCounts {
            for (chapter, count) in chapters where count > 0 {
                for verse in 1...count {
                    let kjv = VerseKey(book: book, chapter: chapter, verse: verse)
                    guard !overridden.contains(kjv) else { continue }
                    if book == 19 {
                        add(kjv, Self.psalm(kjv, chapterCount: count, kjvCounts: chapters, synodalCounts: synodalCounts[19] ?? [:]))
                    } else {
                        add(kjv, kjv)
                    }
                }
            }
        }
        // Надписи псалмів (вірші Синодального перед першим відповідником) ведуть до першого вірша KJV.
        for (chapter, count) in synodalCounts[19] ?? [:] where count > 0 {
            for verse in 1...count {
                let key = VerseKey(book: 19, chapter: chapter, verse: verse)
                if toKJV[key] != nil { break }
                let map = toKJV
                if let next = (verse...count).lazy.compactMap({ map[VerseKey(book: 19, chapter: chapter, verse: $0)] }).first {
                    toKJV[key] = next
                }
            }
        }
        for continuation in Self.continuations { toKJV[continuation.synodal] = continuation.kjv }
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

    public func synodal(fromKJV key: VerseKey) -> VerseKey? { toSynodal[key] }
    public func kjv(fromSynodal key: VerseKey) -> VerseKey? { toKJV[key] }

    /// Усі вірші KJV, з яких складається вірш Синодального, у порядку KJV.
    public func allKJV(fromSynodal key: VerseKey) -> [VerseKey] { (allKJV[key] ?? []).sorted() }

    /// Вірш іншого перекладу; `nil` — відповідника немає.
    public func map(_ key: VerseKey, from source: Translation, to target: Translation) -> VerseKey? {
        switch (source.sharesKJVNumbering, target.sharesKJVNumbering) {
        case (true, true), (false, false): key
        case (true, false): synodal(fromKJV: key)
        case (false, true): kjv(fromSynodal: key)
        }
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
        return Versification(kjvCounts: try counts(.kjv), synodalCounts: try counts(.synodal))
    }
}
