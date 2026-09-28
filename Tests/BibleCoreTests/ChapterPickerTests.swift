import Testing
@testable import BibleCore

@MainActor @Suite struct ChapterPickerTests {
    // @trace FR-37
    @Test func testPickingBookShowsItsChaptersWithoutLeavingCurrentOne() {
        let model = ReaderViewModel { FakeRepository() }
        model.open(Location(book: 43, chapter: 3))
        model.pickBook(8)
        #expect(model.chapterPicker == ChapterPicker(book: 8, chapterCount: 3, current: nil))
        // Текст поточного розділу лишається під вікном.
        #expect(model.location == Location(book: 43, chapter: 3))
        model.pickChapter(2)
        #expect(model.location == Location(book: 8, chapter: 2))
        #expect(model.chapterPicker == nil)
    }

    // @trace FR-37
    @Test func testCurrentBookMarksCurrentChapterAndDismissKeepsPlace() {
        let model = ReaderViewModel { FakeRepository() }
        model.open(Location(book: 43, chapter: 3))
        model.pickBook(43)
        #expect(model.chapterPicker?.current == 3)
        model.dismissChapterPicker()
        #expect(model.chapterPicker == nil)
        #expect(model.location == Location(book: 43, chapter: 3))
        // Без відкритого вікна вибір розділу нічого не робить.
        model.pickChapter(1)
        #expect(model.location == Location(book: 43, chapter: 3))
    }

    // @trace FR-37
    @Test func testSearchResultsCloseWhenChapterPicked() {
        let model = ReaderViewModel { FakeRepository() }
        model.query = "love"
        model.submitSearch()
        #expect(model.results != nil)
        model.pickBook(2)
        model.pickChapter(1)
        #expect(model.results == nil)
        #expect(model.location == Location(book: 2, chapter: 1))
    }

    // @trace FR-37
    @Test func testUnreadableBookGivesNoPicker() {
        let model = ReaderViewModel { throw FakeRepository.Boom() }
        model.pickBook(1)
        #expect(model.chapterPicker == nil)
    }

    // @trace FR-37
    @Test func testNavigatingElsewhereClosesPicker() {
        let model = ReaderViewModel { FakeRepository() }
        model.pickBook(2)
        model.goNext()
        #expect(model.chapterPicker == nil)
        model.pickBook(2)
        model.translation = .synodal
        #expect(model.chapterPicker == nil)
    }

    // @trace FR-37
    @Test func testKeyboardCursorMovesWithinBook() {
        let picker = ChapterPicker(book: 19, chapterCount: 23, current: 5)
        #expect(picker.initialCursor == 5)
        #expect(picker.move(5, by: 1) == 6)
        #expect(picker.move(5, by: -10) == 1)
        #expect(picker.move(20, by: 10) == 23)
        #expect(ChapterPicker(book: 1, chapterCount: 3, current: nil).initialCursor == 1)
    }

    // @trace FR-37
    @Test func testTitleOpensPickerForCurrentBook() {
        let model = ReaderViewModel { FakeRepository() }
        model.open(Location(book: 43, chapter: 2))
        model.pickCurrentBook()
        #expect(model.chapterPicker == ChapterPicker(book: 43, chapterCount: 3, current: 2, origin: .title))
        model.pickBook(8)
        #expect(model.chapterPicker?.origin == .sidebar)
    }
}
