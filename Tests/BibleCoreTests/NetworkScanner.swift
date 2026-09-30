import Foundation

/// Looks for network APIs and addresses in `.swift` files (NFR-2). Lives in tests: it is a check, not app code.
/// The rule is strict: an address in a comment is a finding too. `URL(fileURLWithPath:)` is allowed.
enum NetworkScanner {
    static let tokens = [
        "URLSession", "URLRequest", "URLComponents", "URL(string:", "NSURL(", "NSURLConnection",
        "NWConnection", "NWListener", "NWPathMonitor", "CFStream", "CFSocket", "SCNetworkReachability",
        "getaddrinfo", "WKWebView", "http://", "https://", "ws://", "wss://",
    ]
    /// `import Network`, `@testable import WebKit` etc.
    static var imports: Regex<Substring> { /^\s*(?:@\w+\s+)*import\s+(?:Network|WebKit|CFNetwork)\b/ }

    struct Report {
        /// "path:line: pattern", sorted; the path is relative to the root.
        var findings: [String] = []
        /// How many `.swift` files were scanned: 0 means the check proved nothing.
        var scannedFiles = 0
    }

    static func scan(directories: [URL], relativeTo root: URL, allowing allowed: Set<String> = []) -> Report {
        var report = Report()
        let rootPath = root.standardizedFileURL.path + "/"
        for directory in directories {
            guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                let path = url.standardizedFileURL.path.replacingOccurrences(of: rootPath, with: "")
                guard !allowed.contains(path), let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                report.scannedFiles += 1
                for (index, line) in text.components(separatedBy: .newlines).enumerated() {
                    for token in tokens where line.contains(token) {
                        report.findings.append("\(path):\(index + 1): \(token)")
                    }
                    if line.contains(imports) {
                        report.findings.append("\(path):\(index + 1): import")
                    }
                }
            }
        }
        report.findings.sort()
        return report
    }
}
