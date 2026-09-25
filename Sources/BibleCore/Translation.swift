/// Переклад, який показується на екрані.
public enum Translation: String, CaseIterable, Sendable, Codable {
    case kjv
    case synodal

    public var title: String {
        switch self {
        case .kjv: "KJV"
        case .synodal: "Синодальний"
        }
    }

    /// Ім'я вихідного файлу в `data/raw`.
    public var sourceFileName: String {
        switch self {
        case .kjv: "en_kjv.json"
        case .synodal: "ru_synodal.json"
        }
    }
}
