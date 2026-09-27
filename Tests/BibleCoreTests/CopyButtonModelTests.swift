import Foundation
import Testing
@testable import BibleCore

@Suite struct CopyButtonModelTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)

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
    @Test func testCopiedFeedbackLastsOneAndAHalfSeconds() {
        var model = CopyButtonModel()
        #expect(!model.isShowingCopied(at: start))
        model.markCopied(at: start)
        #expect(model.isShowingCopied(at: start))
        #expect(model.isShowingCopied(at: start.addingTimeInterval(1.4)))
        #expect(!model.isShowingCopied(at: start.addingTimeInterval(1.5)))
        #expect(CopyButtonModel.feedbackDuration == 1.5)
    }

    // @trace FR-17
    @Test func testRepeatedClickExtendsFeedback() {
        var model = CopyButtonModel()
        model.markCopied(at: start)
        model.markCopied(at: start.addingTimeInterval(1))
        #expect(model.isShowingCopied(at: start.addingTimeInterval(2)))
    }
}
