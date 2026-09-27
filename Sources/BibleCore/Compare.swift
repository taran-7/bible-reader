/// Набір і порядок панелей вікна «Порівняти» (FR-36). Щонайменше одна панель лишається.
public struct ComparePanels: Equatable, Codable, Sendable {
    public private(set) var visible: [Translation]

    public init(visible: [Translation] = Translation.allCases) {
        var seen = Set<Translation>()
        let unique = visible.filter { seen.insert($0).inserted }
        self.visible = unique.isEmpty ? Translation.allCases : unique
    }

    /// Закриті панелі в порядку меню — для «+ Переклад».
    public var hidden: [Translation] { Translation.allCases.filter { !visible.contains($0) } }

    public var canClose: Bool { visible.count > 1 }

    public mutating func close(_ translation: Translation) {
        guard canClose else { return }
        visible.removeAll { $0 == translation }
    }

    /// Повернута панель стає праворуч.
    public mutating func add(_ translation: Translation) {
        guard !visible.contains(translation) else { return }
        visible.append(translation)
    }

    public func canMoveLeft(_ translation: Translation) -> Bool { (visible.firstIndex(of: translation) ?? 0) > 0 }

    public func canMoveRight(_ translation: Translation) -> Bool {
        visible.firstIndex(of: translation).map { $0 < visible.count - 1 } ?? false
    }

    public mutating func moveLeft(_ translation: Translation) {
        guard let index = visible.firstIndex(of: translation), index > 0 else { return }
        visible.swapAt(index, index - 1)
    }

    public mutating func moveRight(_ translation: Translation) {
        guard let index = visible.firstIndex(of: translation), index < visible.count - 1 else { return }
        visible.swapAt(index, index + 1)
    }

    /// Перетягування: `translation` стає на місце `target`, решта зсувається.
    /// `false`, якщо порядок не змінився (та сама панель або прихована).
    @discardableResult
    public mutating func move(_ translation: Translation, to target: Translation) -> Bool {
        guard translation != target, let from = visible.firstIndex(of: translation),
              let to = visible.firstIndex(of: target) else { return false }
        visible.remove(at: from)
        visible.insert(translation, at: to)
        return true
    }

    // Зберігаємо як список кодів; невідомі коди (переклад прибрали) відкидаємо, а не губимо всі налаштування.
    public init(from decoder: Decoder) throws {
        let codes = try decoder.singleValueContainer().decode([String].self)
        self.init(visible: codes.compactMap(Translation.init(rawValue:)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(visible.map(\.rawValue))
    }
}

extension Translation {
    /// Нумерація модуля (`numbering` у маніфесті) збігається з KJV; інакше вірші зіставляє `Versification`.
    public var sharesKJVNumbering: Bool { numbering == .kjv }
}

/// Одна панель: вірші в перекладі і посилання мовою перекладу.
public struct ComparePanel: Identifiable, Sendable {
    public let translation: Translation
    public let reference: String
    public let verses: [Verse]
    public var numberingMayDiffer: Bool { !translation.sharesKJVNumbering }
    public var id: Translation { translation }
}

public enum VerseComparison {
    /// Панелі в порядку `panels`; вірші зіставляються за номером.
    public static func load(from repository: BibleRepository, book: Int, chapter: Int, verses: Set<Int>,
                            panels: ComparePanels) throws -> [ComparePanel] {
        guard !verses.isEmpty else { return [] }
        let list = Quote.verseList(Array(verses))
        return try panels.visible.map { translation in
            let texts = try repository.verses(book: book, chapter: chapter, translation: translation)
                .filter { verses.contains($0.verse) }
            // Посилання — за віршами, які справді є в перекладі (частину може бути пропущено).
            let found = texts.isEmpty ? list : Quote.verseList(texts.map(\.verse))
            return ComparePanel(translation: translation,
                                reference: "\(Reference.bookLabel(book, in: translation)) \(chapter):\(found)",
                                verses: texts)
        }
    }
}

/// Що порівнювати: вірші одного розділу. Значення вікна «Порівняти» (FR-36).
public struct CompareRequest: Codable, Hashable, Sendable {
    public let book: Int
    public let chapter: Int
    public let verses: [Int]

    public init(book: Int, chapter: Int, verses: Set<Int>) {
        self.book = book
        self.chapter = chapter
        self.verses = verses.sorted()
    }
}
