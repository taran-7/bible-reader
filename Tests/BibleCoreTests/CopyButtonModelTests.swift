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

    // @trace FR-17
    @Test func testNeighboursShiftInSteps() {
        let selection: Set<Int> = [5, 6, 8]
        #expect([3, 4, 5, 6, 7, 8, 9, 10, 11].map { CopyButtonModel.shift(of: $0, selection: selection) }
                == [0.25, 0.5, 1, 1, 0.5, 1, 0.5, 0.25, 0])
        #expect(CopyButtonModel.shift(of: 1, selection: []) == 0)
        #expect((2...9).map { CopyButtonModel.shift(of: $0, selection: [1, 10]) } == [0.5, 0.25, 0, 0, 0, 0, 0.25, 0.5])
    }
}
