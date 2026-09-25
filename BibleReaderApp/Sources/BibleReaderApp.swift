import BibleCore
import SwiftUI

@main
struct BibleReaderApp: App {
    @State private var model = ReaderViewModel {
        guard let url = Bundle.main.url(forResource: "bible", withExtension: "sqlite") else {
            throw RepositoryError.cannotOpen(path: "bible.sqlite", reason: "файл відсутній у бандлі")
        }
        return try SQLiteBibleRepository(path: url)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}
