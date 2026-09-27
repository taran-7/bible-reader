import Foundation

/// Шукає мережеві API й адреси в `.swift`-файлах (NFR-2). Живе в тестах: це перевірка, а не код додатка.
/// Правило суворе: адреса в коментарі теж знахідка. `URL(fileURLWithPath:)` дозволено.
enum NetworkScanner {
    static let tokens = [
        "URLSession", "URLRequest", "URLComponents", "URL(string:", "NSURL(", "NSURLConnection",
        "NWConnection", "NWListener", "NWPathMonitor", "CFStream", "CFSocket", "SCNetworkReachability",
        "getaddrinfo", "WKWebView", "http://", "https://", "ws://", "wss://",
    ]
    /// `import Network`, `@testable import WebKit` тощо.
    static var imports: Regex<Substring> { /^\s*(?:@\w+\s+)*import\s+(?:Network|WebKit|CFNetwork)\b/ }

    struct Report {
        /// «шлях:рядок: шаблон», відсортовані; шлях — відносно кореня.
        var findings: [String] = []
        /// Скільки `.swift`-файлів переглянуто: 0 означає, що перевірка нічого не довела.
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
