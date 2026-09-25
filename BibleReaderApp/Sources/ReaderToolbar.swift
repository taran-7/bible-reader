import BibleCore
import SwiftUI

struct ReaderToolbar: ToolbarContent {
    @Bindable var model: ReaderViewModel

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
            Button("Наступний розділ", systemImage: "chevron.right") { model.goNext() }
                .disabled(!model.canGoNext)
                .keyboardShortcut("]", modifiers: .command)
        }
        ToolbarItem(placement: .principal) {
            Picker("Розділ", selection: chapter) {
                ForEach(Array(1...max(model.chapterCount, 1)), id: \.self) { Text("Розділ \($0)").tag($0) }
            }
            .fixedSize()
        }
        ToolbarItem {
            Picker("Переклад", selection: $model.translation) {
                ForEach(Translation.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
