import Foundation
import Testing
@testable import BibleCore

/// NFR-1 і NFR-5 на рівні налаштувань і ресурсів; зібраний Release `.app` перевіряє `scripts/check-platform.mjs`.
@Suite struct PlatformTests {
    static let root = TestSupport.repoRoot

    // @trace NFR-1
    @Test func testTargetsMacOS14OnAppleSilicon() throws {
        let project = try String(contentsOf: Self.root.appendingPathComponent("BibleReaderApp/project.yml"), encoding: .utf8)
        #expect(project.contains(#"macOS: "14.0""#))
        #expect(project.contains("ARCHS: arm64"))
        let package = try String(contentsOf: Self.root.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(package.contains(".macOS(.v14)"))
    }

    // @trace NFR-5
    @Test func testResourcesLeaveRoomForCode() throws {
        func size(_ url: URL) throws -> Int {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            guard values.isDirectory == true else { return values.fileSize ?? 0 }
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            return try files.reduce(0) { $0 + (try size($1)) }
        }
        // Ресурси .app: база з усіма перекладами і шрифти; ~10 МБ лишаємо на код і системні файли.
        let resources = try size(TestSupport.realDatabase) + size(Self.root.appendingPathComponent("BibleReaderApp/Resources/Fonts"))
        let megabytes = Double(resources) / 1_048_576
        #expect(megabytes > 10, "база порожня? \(megabytes) МБ")
        #expect(megabytes < 90, "ресурси \(megabytes) МБ — разом із кодом .app перевищить 100 МБ")
    }
}
