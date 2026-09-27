import Foundation

/// Де шукати `bible.sqlite`: `BIBLE_READER_DB` (для UI-тестів) має пріоритет над бандлом.
public enum DatabaseLocation {
    public static let environmentKey = "BIBLE_READER_DB"

    public static func url(environment: [String: String], bundled: URL?) throws -> URL {
        if let path = environment[environmentKey], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        guard let bundled else {
            throw RepositoryError.cannotOpen(path: "bible.sqlite", reason: "файл відсутній у бандлі")
        }
        return bundled
    }
}
