/// Переклади, вибрані для «Порівняти» (FR-36), у порядку колонок. Щонайменше один лишається.
public struct ComparePanels: Equatable, Codable, Sendable {
    public private(set) var visible: [Translation]

    public init(visible: [Translation] = Translation.allCases) {
        var seen = Set<Translation>()
        let unique = visible.filter { seen.insert($0).inserted }
        self.visible = unique.isEmpty ? Translation.allCases : unique
    }

    /// Перемикач у вікні вибору перекладів; останній вибраний лишається.
    public mutating func toggle(_ translation: Translation) {
        if visible.contains(translation) { close(translation) } else { add(translation) }
    }

    public var canClose: Bool { visible.count > 1 }

    public mutating func close(_ translation: Translation) {
        guard canClose else { return }
        visible.removeAll { $0 == translation }
    }

    /// Повернутий переклад стає праворуч.
    public mutating func add(_ translation: Translation) {
        guard !visible.contains(translation) else { return }
        visible.append(translation)
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

/// Режим «Порівняти» в головному вікні (FR-36): увесь розділ колонками — переклад на екрані і вибрані,
/// рядки вирівняні за віршами основного перекладу, виділені вірші підсвічені.
public struct Comparison: Sendable {
    public let location: Location
    /// Колонки зліва направо; перша — переклад на екрані.
    public let translations: [Translation]
    public let highlighted: Set<Int>
    public let rows: [CompareRow]

    /// Заголовок колонки мовою її перекладу; розділ — основного (`location` завжди в межах канону).
    public func title(of translation: Translation) -> String {
        "\(Book.all[location.book - 1].name(in: translation)) \(location.chapter)"
    }
}

/// Рядок порівняння: вірш основного перекладу і відповідні вірші кожного іншого (у порядку колонок).
public struct CompareRow: Identifiable, Sendable {
    public let primary: Verse
    public let others: [[Verse]]
    public var id: Int { primary.verse }
}
