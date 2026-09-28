import BibleCore
import SwiftUI

struct BookList: View {
    let model: ReaderViewModel
    let fontSize: Double
    /// Розмір шрифту віршів — для номерів у вікні розділів.
    let verseFontSize: Double
    @Environment(\.theme) private var theme
    @Environment(UserData.self) private var userData

    /// Підсвічено книгу з відкритим вікном розділів, інакше — поточну.
    private var highlighted: Int { model.chapterPicker?.book ?? model.location.book }

    /// Вибір у `List` — це книга з відкритим вікном розділів; без вікна нічого не вибрано,
    /// тож і клік по поточній книзі, і стрілки ↑ ↓ відкривають вікно (FR-37, NFR-4).
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
                // Клік показує розділи книги поверх тексту (FR-37), а не відкриває одразу перший.
                Text(book.name(in: model.translation))
                    .font(.system(size: fontSize))
                    .foregroundStyle(Color(theme.text))
                    .accessibilityIdentifier("book-\(book.number)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Вікно розділів прикріплене збоку до цієї книги.
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
