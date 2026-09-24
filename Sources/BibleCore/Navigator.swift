/// Місце читання: книга і розділ.
public struct Location: Hashable, Sendable {
    public let book: Int
    public let chapter: Int

    public init(book: Int, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }
}

/// Сусідні розділи з переходом між книгами; `nil` на межах Біблії.
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
        return Location(book: location.book - 1, chapter: chapterCount(location.book - 1))
    }
}
