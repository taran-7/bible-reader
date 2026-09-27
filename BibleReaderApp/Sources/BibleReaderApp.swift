import BibleCore
import SwiftUI

@main
struct BibleReaderApp: App {
    @State private var model = ReaderViewModel {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment // BIBLE_READER_DB для UI-тестів
        #else
        let environment: [String: String] = [:]
        #endif
        let url = try DatabaseLocation.url(
            environment: environment,
            bundled: Bundle.main.url(forResource: "bible", withExtension: "sqlite"))
        return try SQLiteBibleRepository(path: url)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}
