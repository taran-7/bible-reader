import Foundation

/// Шукає мережеві API й адреси в `.swift`-файлах (NFR-2). Живе в тестах: це перевірка, а не код додатка.
enum NetworkScanner {
    static let patterns = ["URLSession", "URLRequest", "NSURLConnection", "import Network", "WKWebView", "http://", "https://"]

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
                    for pattern in patterns where line.contains(pattern) {
                        report.findings.append("\(path):\(index + 1): \(pattern)")
                    }
                }
            }
        }
        report.findings.sort()
        return report
    }
}
