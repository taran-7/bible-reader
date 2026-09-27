import Foundation

/// Кнопка копіювання на виділенні (FR-17): де стоїть і скільки триває «Скопійовано».
public struct CopyButtonModel: Equatable, Sendable {
    public static let feedbackDuration: TimeInterval = 1.5

    private var copiedAt: Date?

    public init() {}

    /// Вірш, над яким стоїть кнопка: перший виділений; без виділення кнопки немає.
    public static func anchorVerse(for selection: Set<Int>) -> Int? { selection.min() }

    public mutating func markCopied(at date: Date) { copiedAt = date }

    public func isShowingCopied(at date: Date) -> Bool {
        guard let copiedAt else { return false }
        return date.timeIntervalSince(copiedAt) < Self.feedbackDuration
    }
}
