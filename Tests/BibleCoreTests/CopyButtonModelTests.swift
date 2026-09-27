import Testing
@testable import BibleCore

@Suite struct CopyButtonModelTests {
    // @trace FR-17
    @Test func testNoSelectionNoButton() {
        #expect(CopyButtonModel.anchorVerse(for: []) == nil)
    }

    // @trace FR-17
    @Test func testAnchorIsFirstSelectedVerse() {
        #expect(CopyButtonModel.anchorVerse(for: [18, 16, 17]) == 16)
        #expect(CopyButtonModel.anchorVerse(for: [3]) == 3)
    }

    // @trace FR-17
    @Test func testFeedbackLastsOneAndAHalfSeconds() {
        #expect(CopyButtonModel.feedbackDuration == .seconds(1.5))
    }
}
