import Foundation
import Testing
@testable import BibleCore

/// NFR-2: the app is offline: network APIs and addresses are forbidden in code, except the illustrations module (FR-33…FR-35).
@Suite struct NetworkIsolationTests {
    /// Files (path from the repository root) allowed to use the network: the single illustrations network file.
    static let allowedFiles: Set<String> = ["Sources/BibleCore/IllustrationNetwork.swift"]

    // @trace NFR-2
    @Test func testFindsNetworkUsage() throws {
        let dir = try TestSupport.tempDirectory()
        try "import Foundation\nlet task = URLSession.shared\n".write(to: dir.appendingPathComponent("Bad.swift"), atomically: true, encoding: .utf8)
        try "let ok = URL(fileURLWithPath: \"/tmp\")\n".write(to: dir.appendingPathComponent("Good.swift"), atomically: true, encoding: .utf8)
        try "@testable import Network\nlet d = Data(contentsOf: URL(string: host)!)\n".write(to: dir.appendingPathComponent("Sneaky.swift"), atomically: true, encoding: .utf8)
        let report = NetworkScanner.scan(directories: [dir], relativeTo: dir)
        #expect(report.findings == ["Bad.swift:2: URLSession", "Sneaky.swift:1: import", "Sneaky.swift:2: URL(string:"])
        #expect(report.scannedFiles == 3)
    }

    // @trace NFR-2
    @Test func testAppCodeHasNoNetworkAccess() {
        let root = TestSupport.repoRoot
        let report = NetworkScanner.scan(
            directories: [root.appendingPathComponent("Sources"), root.appendingPathComponent("BibleReaderApp/Sources")],
            relativeTo: root,
            allowing: Self.allowedFiles)
        #expect(report.findings.isEmpty, "\(report.findings)")
        // An empty scope is not evidence (vacuous pass): the paths must lead to real code.
        #expect(report.scannedFiles >= 20, "переглянуто \(report.scannedFiles) файлів")
    }
}
