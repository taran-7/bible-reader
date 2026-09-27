import BibleCore
import SwiftUI

struct BookList: View {
    let model: ReaderViewModel
    let fontSize: Double
    @Environment(\.theme) private var theme

    private var selection: Binding<Int?> {
        Binding(
            get: { model.location.book },
            set: { book in
                if let book, book != model.location.book {
                    model.open(Location(book: book, chapter: 1))
                }
            })
    }

    var body: some View {
        List(selection: selection) {
            section("Старий Заповіт", .old)
            section("Новий Заповіт", .new)
        }
        .modifier(ChromeBackground(color: theme.sidebar))
    }

    private func section(_ title: String, _ testament: Testament) -> some View {
        Section {
            ForEach(model.books.filter { $0.testament == testament }) { book in
                Text(book.name(in: model.translation))
                    .font(.system(size: fontSize))
                    .foregroundStyle(Color(theme.text))
                    .tag(book.number)
            }
        } header: {
            Text(title).foregroundStyle(Color(theme.secondaryText))
        }
    }
}
