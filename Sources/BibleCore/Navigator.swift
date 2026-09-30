/// A reading position: book and chapter.
public struct Location: Hashable, Sendable {
    public let book: Int
    public let chapter: Int

    public init(book: Int, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }
}

/// Neighboring chapters, crossing between books; `nil` at the ends of the Bible.
public struct Navigator {
    private let chapterCount: (Int) -> Int

    public init(chapterCount: @escaping (Int) -> Int) {
        self.chapterCount = chapterCount
    }

    public func next(from location: Location) -> Location? {
        if location.chapter < chapterCount(location.book) {
            return Location(book: location.book, chapter: location.chapter + 1)
        }
        guard location.book < Book.all.count else { return nil }
        return Location(book: location.book + 1, chapter: 1)
    }

    public func previous(from location: Location) -> Location? {
        if location.chapter > 1 {
            return Location(book: location.book, chapter: location.chapter - 1)
        }
        guard location.book > 1 else { return nil }
        // A book without chapters (a corrupted database) would give "chapter 0".
        let count = chapterCount(location.book - 1)
        guard count > 0 else { return nil }
        return Location(book: location.book - 1, chapter: count)
    }
}
