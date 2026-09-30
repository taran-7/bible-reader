import BibleCore
import SwiftUI

struct BookList: View {
    let model: ReaderViewModel
    let fontSize: Double
    /// The verse font size, for numbers in the chapter window.
    let verseFontSize: Double
    @Environment(\.theme) private var theme
    @Environment(UserData.self) private var userData

    /// The book with an open chapter window is highlighted, otherwise the current one.
    private var highlighted: Int { model.chapterPicker?.book ?? model.location.book }

    /// The `List` selection is the book with an open chapter window; without a window nothing is selected,
    /// so both a click on the current book and the ↑ ↓ arrows open the window (FR-37, NFR-4).
    private var selection: Binding<Int?> {
        Binding(
            get: { model.chapterPicker?.book },
            set: { book in
                if let book { model.pickBook(book) } else { model.dismissChapterPicker() }
            })
    }

    var body: some View {
        List(selection: selection) {
            if !userData.bookmarks.isEmpty {
                Section {
                    ForEach(userData.bookmarks) { bookmark in
                        Button {
                            model.openCanonical(book: bookmark.target.book, chapter: bookmark.target.chapter, verse: bookmark.target.verse)
                        } label: {
                            Label(model.localReference(book: bookmark.target.book, chapter: bookmark.target.chapter,
                                                       verse: bookmark.target.verse).format(in: model.translation),
                                  systemImage: bookmark.target.verse == nil ? "book" : "bookmark")
                                .font(.system(size: fontSize))
                                .foregroundStyle(Color(theme.text))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bookmark-row")
                        .contextMenu {
                            Button("Прибрати закладку") { userData.toggleBookmark(bookmark.target) }
                        }
                    }
                } header: {
                    Text("Закладки").foregroundStyle(Color(theme.secondaryText))
                }
            }
            section("Старий Заповіт", .old)
            section("Новий Заповіт", .new)
        }
        .modifier(ChromeBackground(color: theme.sidebar))
    }

    private func section(_ title: String, _ testament: Testament) -> some View {
        Section {
            ForEach(model.books.filter { $0.testament == testament }) { book in
                // A click shows the book's chapters over the text (FR-37) instead of opening the first one right away.
                Text(book.name(in: model.translation))
                    .font(.system(size: fontSize))
                    .foregroundStyle(Color(theme.text))
                    .accessibilityIdentifier("book-\(book.number)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The chapter window is attached to the side of this book.
                    .popover(isPresented: model.chapterPickerBinding(book: book.number, origin: .sidebar),
                             arrowEdge: .trailing) {
                        if let picker = model.chapterPicker {
                            ChapterPickerView(model: model, picker: picker, fontSize: verseFontSize)
                        }
                    }
                    .tag(book.number)
                    .listRowBackground(
                        book.number == highlighted
                            ? RoundedRectangle(cornerRadius: 6).fill(Color(theme.sidebarSelection)).padding(.horizontal, 8)
                            : nil)
            }
        } header: {
            Text(title).foregroundStyle(Color(theme.secondaryText))
        }
    }
}
