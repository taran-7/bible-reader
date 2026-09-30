/// Translations chosen for "Compare" (FR-36), in column order. At least one stays.
public struct ComparePanels: Equatable, Codable, Sendable {
    public private(set) var visible: [Translation]

    public init(visible: [Translation] = Translation.allCases) {
        var seen = Set<Translation>()
        let unique = visible.filter { seen.insert($0).inserted }
        self.visible = unique.isEmpty ? Translation.allCases : unique
    }

    /// A toggle in the translation picker; the last selected one stays.
    public mutating func toggle(_ translation: Translation) {
        if visible.contains(translation) { close(translation) } else { add(translation) }
    }

    public var canClose: Bool { visible.count > 1 }

    public mutating func close(_ translation: Translation) {
        guard canClose else { return }
        visible.removeAll { $0 == translation }
    }

    /// A returned translation goes to the right.
    public mutating func add(_ translation: Translation) {
        guard !visible.contains(translation) else { return }
        visible.append(translation)
    }

    // Stored as a list of codes; unknown codes (a removed translation) are dropped instead of losing all settings.
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
    /// The module's numbering (`numbering` in the manifest) matches KJV; otherwise `Versification` maps the verses.
    public var sharesKJVNumbering: Bool { numbering == .kjv }
}

/// "Compare" mode in the main window (FR-36): the whole chapter in columns, the on-screen translation and the chosen ones,
/// rows aligned by the main translation's verses, selected verses highlighted.
public struct Comparison: Sendable {
    public let location: Location
    /// Columns from left to right; the first is the on-screen translation.
    public let translations: [Translation]
    public let highlighted: Set<Int>
    public let rows: [CompareRow]

    /// A column header in its translation's language; the chapter is the main one's (`location` is always within the canon).
    public func title(of translation: Translation) -> String {
        "\(Book.all[location.book - 1].name(in: translation)) \(location.chapter)"
    }
}

/// A comparison row: a verse of the main translation and the corresponding verses of each other one (in column order).
public struct CompareRow: Identifiable, Sendable {
    public let primary: Verse
    public let others: [[Verse]]
    public var id: Int { primary.verse }
}
