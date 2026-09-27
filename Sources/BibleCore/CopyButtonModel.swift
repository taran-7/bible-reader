import Foundation

/// Кнопка копіювання на виділенні (FR-17): де стоїть і скільки триває «Скопійовано».
public enum CopyButtonModel {
    public static let feedbackDuration: Duration = .milliseconds(1500)

    /// Вірш, над яким стоїть кнопка: перший виділений; без виділення кнопки немає.
    public static func anchorVerse(for selection: Set<Int>) -> Int? { selection.min() }
}
