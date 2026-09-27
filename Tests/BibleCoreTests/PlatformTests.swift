import Foundation
import Testing
@testable import BibleCore

/// NFR-1 і NFR-5 на рівні налаштувань і ресурсів; зібраний Release `.app` перевіряє `scripts/check-platform.mjs`.
@Suite struct PlatformTests {
    static let root = TestSupport.repoRoot

    // @trace NFR-1
    @Test func testTargetsMacOS14OnAppleSilicon() throws {
        let project = try String(contentsOf: Self.root.appendingPathComponent("BibleReaderApp/project.yml"), encoding: .utf8)
        let lines = project.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(lines.contains(#"macOS: "14.0""#))
        #expect(lines.contains("ARCHS: arm64"))
        let package = try String(contentsOf: Self.root.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(package.contains(".macOS(.v14)"))
    }

    // Попередня перевірка до збірки; доказ NFR-5 — розмір зібраного .app у scripts/check-platform.mjs (ті самі 100 МБ).
    // @trace NFR-5
    @Test func testResourcesLeaveRoomForCode() throws {
        func size(_ url: URL) throws -> Int {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            guard values.isDirectory == true else { return values.fileSize ?? 0 }
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            return try files.reduce(0) { $0 + (try size($1)) }
        }
        // Усі ресурси .app (BibleReaderApp/Resources) з базою, зібраною з поточних data/raw; ~10 МБ лишаємо на код.
        let resourcesDir = Self.root.appendingPathComponent("BibleReaderApp/Resources")
        let bundledDB = resourcesDir.appendingPathComponent("bible.sqlite")
        let others = try FileManager.default.contentsOfDirectory(at: resourcesDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != bundledDB.lastPathComponent }
        let resources = try size(TestSupport.realDatabase) + others.reduce(0) { $0 + (try size($1)) }
        let megabytes = Double(resources) / 1_048_576
        #expect(megabytes > 10, "база порожня? \(megabytes) МБ")
        #expect(megabytes < 90, "ресурси \(megabytes) МБ — разом із кодом .app перевищить 100 МБ")
    }
}
