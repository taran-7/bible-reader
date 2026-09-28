import Foundation

/// Кнопка копіювання на виділенні (FR-17): де стоїть і скільки триває «Скопійовано».
public enum CopyButtonModel {
    public static let feedbackDuration: Duration = .milliseconds(1500)

    /// Вірш, над яким стоїть кнопка: перший виділений; без виділення кнопки немає.
    public static func anchorVerse(for selection: Set<Int>) -> Int? { selection.min() }

    /// Наскільки рядок відсувається від кнопок (0…1 від повного відступу): виділені вірші — повністю,
    /// сусіди — сходинками ½ і ¼, щоб перехід до решти тексту був плавним (запит власника 2026-09-28).
    public static func shift(of verse: Int, selection: Set<Int>) -> Double {
        guard let first = selection.min(), let last = selection.max() else { return 0 }
        if selection.contains(verse) { return 1 }
        let distance = verse < first ? first - verse : verse > last ? verse - last : 1
        switch distance {
        case 1: return 0.5
        case 2: return 0.25
        default: return 0
        }
    }
}
