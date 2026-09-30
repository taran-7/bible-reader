import Foundation
import Testing
@testable import BibleCore

/// NFR-1 and NFR-5 at the settings and resources level; the built Release `.app` is checked by `scripts/check-platform.mjs`.
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

    // A pre-build check; the NFR-5 evidence is the built .app size in scripts/check-platform.mjs (the same 100 MB).
    // @trace NFR-5
    @Test func testResourcesLeaveRoomForCode() throws {
        func size(_ url: URL) throws -> Int {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            guard values.isDirectory == true else { return values.fileSize ?? 0 }
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            return try files.reduce(0) { $0 + (try size($1)) }
        }
        // All .app resources (BibleReaderApp/Resources) with the database built from the current data/raw; ~10 MB is left for code.
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
