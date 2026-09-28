import BibleCore
import SwiftUI

struct ReaderToolbar: ToolbarContent {
    @Bindable var model: ReaderViewModel
    let userData: UserData
    @Bindable var preferences: PreferencesStore
    /// Елементи тулбара живуть у `NSToolbar`, тож масштаб задаємо кожному явно.
    let scale: InterfaceScale

    /// Паралельний переклад, що збігся з основним, показується як «Вимкнено».
    private var parallel: Binding<BibleCore.Translation?> {
        Binding(
            get: { preferences.preferences.parallelTranslation == model.translation ? nil : preferences.preferences.parallelTranslation },
            set: { preferences.preferences.parallelTranslation = $0 })
    }

    private var chapterTitle: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Попередній розділ", systemImage: "chevron.left") { model.goPrevious() }
                .disabled(!model.canGoPrevious)
                .keyboardShortcut("[", modifiers: .command)
                .controlSize(scale.controlSize)
            Button("Наступний розділ", systemImage: "chevron.right") { model.goNext() }
                .disabled(!model.canGoNext)
                .keyboardShortcut("]", modifiers: .command)
                .controlSize(scale.controlSize)
            // Назва розділу — кнопка: розділи відкритої книги донизу (FR-37).
            Button { model.pickCurrentBook() } label: {
                HStack(spacing: 4) {
                    Text(verbatim: chapterTitle).font(.headline)
                    Image(systemName: "chevron.down").imageScale(.small)
                }
            }
            .help("Обрати розділ")
            .accessibilityLabel("Розділ: \(chapterTitle)")
            .accessibilityIdentifier("chapter-title")
            .controlSize(scale.controlSize)
            .popover(isPresented: model.chapterPickerBinding(book: model.location.book, origin: .title),
                     arrowEdge: .bottom) {
                if let picker = model.chapterPicker {
                    ChapterPickerView(model: model, picker: picker, fontSize: preferences.preferences.verseFontSize)
                }
            }
        }
        ToolbarItem {
            let chapter = model.canonicalChapter
            let marked = userData.isBookmarked(chapter)
            Button(marked ? "Прибрати закладку розділу" : "Закладка на розділ",
                   systemImage: marked ? "bookmark.fill" : "bookmark") { userData.toggleBookmark(chapter) }
                .help(marked ? "Прибрати закладку розділу (⌘D)" : "Закладка на розділ (⌘D)")
                .accessibilityIdentifier("bookmark-chapter")
                .controlSize(scale.controlSize)
        }
        ToolbarItem {
            // Другий переклад поруч (FR-26); вибір зберігається в налаштуваннях.
            Menu {
                Picker("Паралельно", selection: parallel) {
                    Text("Вимкнено").tag(BibleCore.Translation?.none)
                    ForEach(BibleCore.Translation.allCases.filter { $0 != model.translation }, id: \.self) {
                        Text($0.menuTitle).tag(BibleCore.Translation?.some($0))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(model.parallelTranslation.map { "Поруч: \($0.title)" } ?? "Паралельно",
                      systemImage: "rectangle.split.2x1")
            }
            .help("Другий переклад поруч")
            .accessibilityIdentifier("parallel")
            .controlSize(scale.controlSize)
        }
        ToolbarItem {
            // Меню, а не сегменти: перекладів чотири й далі більшатиме; у пунктах — мова.
            Menu {
                Picker("Переклад", selection: $model.translation) {
                    ForEach(Translation.allCases, id: \.self) { Text($0.menuTitle).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Text(model.translation.title)
            }
            .help("Переклад")
            .accessibilityLabel("Переклад: \(model.translation.title)")
            .accessibilityIdentifier("translation")
            .controlSize(scale.controlSize)
        }
    }
}
