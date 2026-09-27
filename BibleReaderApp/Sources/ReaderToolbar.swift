import BibleCore
import SwiftUI

struct ReaderToolbar: ToolbarContent {
    @Bindable var model: ReaderViewModel
    let userData: UserData
    /// Елементи тулбара живуть у `NSToolbar`, тож масштаб задаємо кожному явно.
    let scale: InterfaceScale

    private var chapter: Binding<Int> {
        Binding(
            get: { model.location.chapter },
            set: { model.open(Location(book: model.location.book, chapter: $0)) })
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
        }
        ToolbarItem(placement: .principal) {
            Picker("Розділ", selection: chapter) {
                ForEach(Array(1...max(model.chapterCount, 1)), id: \.self) { Text("Розділ \($0)").tag($0) }
            }
            .controlSize(scale.controlSize)
            .fixedSize()
        }
        ToolbarItem {
            let chapter = Bookmark.Target(book: model.location.book, chapter: model.location.chapter, verse: nil)
            let marked = userData.isBookmarked(chapter)
            Button(marked ? "Прибрати закладку розділу" : "Закладка на розділ",
                   systemImage: marked ? "bookmark.fill" : "bookmark") { userData.toggleBookmark(chapter) }
                .help(marked ? "Прибрати закладку розділу (⌘D)" : "Закладка на розділ (⌘D)")
                .accessibilityIdentifier("bookmark-chapter")
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
            .accessibilityIdentifier("translation")
            .controlSize(scale.controlSize)
        }
    }
}
