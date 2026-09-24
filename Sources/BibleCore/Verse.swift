public struct VerseID: Hashable, Sendable {
    public let translation: Translation
    public let book: Int
    public let chapter: Int
    public let verse: Int
}

public struct Verse: Identifiable, Hashable, Sendable {
    public let translation: Translation
    public let book: Int
    public let chapter: Int
    public let verse: Int
    public let text: String

    public init(translation: Translation, book: Int, chapter: Int, verse: Int, text: String) {
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.text = text
    }

    public var id: VerseID {
        VerseID(translation: translation, book: book, chapter: chapter, verse: verse)
    }
}
