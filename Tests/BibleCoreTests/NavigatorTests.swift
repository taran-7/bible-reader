import Testing
@testable import BibleCore

@Suite struct NavigatorTests {
    // Genesis 50, Exodus 40, …, Revelation 22.
    let navigator = Navigator { book in
        switch book {
        case 1: 50
        case 2: 40
        case 66: 22
        default: 10
        }
    }

    // @trace FR-6
    @Test func testNextWithinBook() {
        #expect(navigator.next(from: Location(book: 1, chapter: 1)) == Location(book: 1, chapter: 2))
    }

    // @trace FR-6
    @Test func testNextAtBookEnd() {
        #expect(navigator.next(from: Location(book: 1, chapter: 50)) == Location(book: 2, chapter: 1))
    }

    // @trace FR-6
    @Test func testPreviousAtBookStart() {
        #expect(navigator.previous(from: Location(book: 2, chapter: 1)) == Location(book: 1, chapter: 50))
    }

    // @trace FR-6
    @Test func testPreviousAtStartIsNil() {
        #expect(navigator.previous(from: Location(book: 1, chapter: 1)) == nil)
    }

    // @trace FR-6
    @Test func testNextAtEndIsNil() {
        #expect(navigator.next(from: Location(book: 66, chapter: 22)) == nil)
    }

    // @trace FR-6
    @Test func testPreviousIntoEmptyBookIsNil() {
        // A corrupted database: the previous book has 0 chapters, which must not give "chapter 0" (tech debt #11).
        let broken = Navigator { $0 == 1 ? 0 : 10 }
        #expect(broken.previous(from: Location(book: 2, chapter: 1)) == nil)
        #expect(broken.previous(from: Location(book: 2, chapter: 2)) == Location(book: 2, chapter: 1))
    }
}
