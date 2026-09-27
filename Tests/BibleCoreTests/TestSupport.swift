import Foundation
import GRDB
@testable import BibleCore

enum TestSupport {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let rawData = repoRoot.appendingPathComponent("data/raw")

    static func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BibleCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Дві книги в кожному з чотирьох перекладів у форматі thiagobodruk.
    static func writeFixture(to dir: URL, kjv: String? = nil, synodal: String? = nil, ohienko: String? = nil, bkr: String? = nil) throws {
        let kjvJSON = kjv ?? """
        [{"abbrev":"gn","name":"Genesis","chapters":[["In the beginning God created the heaven and the earth.","And the earth was {without} form."]]},
         {"abbrev":"ex","name":"Exodus","chapters":[["Now these are the names."],["And there went a man."]]}]
        """
        let synodalJSON = synodal ?? """
        [{"abbrev":"1","name":"Genesis","chapters":[["В начале сотворил Бог небо и землю.","Земля же была безвидна и пуста."]]},
         {"abbrev":"2","name":"Exodus","chapters":[["Вот имена сынов Израилевых."],["Некто из племени Левиина."]]}]
        """
        let ohienkoJSON = ohienko ?? """
        [{"abbrev":"1","name":"Genesis","chapters":[["На початку Бог створив небо та землю.","А земля була пуста та порожня."]]},
         {"abbrev":"2","name":"Exodus","chapters":[["Оце ймення Ізраїлевих синів."],["І пішов один чоловік."]]}]
        """
        let bkrJSON = bkr ?? """
        [{"abbrev":"1","name":"Genesis","chapters":[["Na počátku stvořil Bůh nebe a zemi.","Země pak byla nesličná a pustá."]]},
         {"abbrev":"2","name":"Exodus","chapters":[["Tato jsou jména synů Izraelských."],["Odšel pak muž jeden."]]}]
        """
        for (json, translation) in [(ohienkoJSON, Translation.ohienko), (bkrJSON, .bkr)] where !json.isEmpty {
            try Data(json.utf8).write(to: dir.appendingPathComponent(translation.sourceFileName))
        }
        if !kjvJSON.isEmpty {
            try Data(kjvJSON.utf8).write(to: dir.appendingPathComponent(Translation.kjv.sourceFileName))
        }
        if !synodalJSON.isEmpty {
            try Data(synodalJSON.utf8).write(to: dir.appendingPathComponent(Translation.synodal.sourceFileName))
        }
    }

    static func count(_ sql: String, in db: URL) throws -> Int {
        try DatabaseQueue(path: db.path).read { try Int.fetchOne($0, sql: sql) ?? 0 }
    }

    static func string(_ sql: String, in db: URL) throws -> String? {
        try DatabaseQueue(path: db.path).read { try String.fetchOne($0, sql: sql) }
    }

    /// База з реальних даних, імпортується один раз на прогін тестів.
    static let realDatabase: URL = {
        let out = try! tempDirectory().appendingPathComponent("bible.sqlite")
        try! BibleImporter.run(rawDirectory: rawData, output: out)
        return out
    }()
}
