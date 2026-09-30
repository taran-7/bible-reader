import XCTest

extension XCUIApplication {
    /// A visible button with an identifier. After a selection change SwiftUI keeps an old copy of the button
    /// with a 0×0 frame in the tree for a while, and `firstMatch` sometimes returns exactly that one.
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
