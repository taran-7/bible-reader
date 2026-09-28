import Foundation

/// Кнопка копіювання на виділенні (FR-17): де стоїть і скільки триває «Скопійовано».
public enum CopyButtonModel {
    public static let feedbackDuration: Duration = .milliseconds(1500)

    /// Вірш, над яким стоїть кнопка: перший виділений; без виділення кнопки немає.
    public static func anchorVerse(for selection: Set<Int>) -> Int? { selection.min() }

    /// Наскільки рядок відсувається від кнопок (0…1 від повного відступу): виділені вірші — повністю,
    /// сусіди — сходинками ½ і ¼, щоб перехід до решти тексту був плавним (запит власника 2026-09-28).
    public static func shift(of verse: Int, selection: Set<Int>) -> Double {
        // Відстань до найближчого виділеного: у проміжку {1, 10} вірші 5–6 теж стоять на місці.
        guard let distance = selection.map({ abs($0 - verse) }).min() else { return 0 }
        switch distance {
        case 0: return 1
        case 1: return 0.5
        case 2: return 0.25
        default: return 0
        }
    }
}
