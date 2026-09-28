import XCTest

extension XCUIApplication {
    /// Видима кнопка з ідентифікатором. Після зміни виділення SwiftUI якийсь час лишає в дереві
    /// стару копію кнопки з рамкою 0×0, і `firstMatch` інколи повертає саме її.
    func visibleButton(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement? {
        let buttons = self.buttons.matching(identifier: identifier)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let button = buttons.allElementsBoundByIndex.first(where: { !$0.frame.isEmpty && $0.isHittable }) {
                return button
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return nil
    }
}
