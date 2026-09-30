import Foundation
import Testing
@testable import BibleCore

@Suite struct LaunchClockTests {
    // @trace NFR-3
    @Test func testProcessStartIsInThePast() throws {
        let start = try #require(LaunchClock.processStart())
        #expect(start <= Date())
        #expect(Date().timeIntervalSince(start) < 3600)
        let elapsed = try #require(LaunchClock.millisecondsSinceStart())
        #expect(elapsed >= 0)
    }

    // @trace NFR-3
    @Test func testUnknownProcessHasNoStart() {
        #expect(LaunchClock.processStart(pid: -1) == nil)
    }

    // @trace NFR-3
    @Test func testOpeningRealDatabaseIsFast() throws {
        // The heaviest part of launch in BibleCore: opening the database and the first chapter.
        // Best of three: parallel tests sometimes take the CPU, and we measure the code, not the load.
        let clock = ContinuousClock()
        let times = try (0..<3).map { _ in
            try clock.measure {
                let repository = try SQLiteBibleRepository(path: TestSupport.realDatabase)
                _ = try repository.books(translation: .kjv)
                _ = try repository.verses(book: 1, chapter: 1, translation: .kjv)
            }
        }
        let best = try #require(times.min())
        #expect(best < .milliseconds(300), "\(times)")
    }
}

@MainActor @Suite struct LaunchReportTests {
    // @trace NFR-3
    @Test func testFirstChapterIsMarkedOnce() {
        let model = ReaderViewModel { FakeRepository() }
        #expect(model.launchMilliseconds == nil)
        model.markFirstChapterShown()
        let first = model.launchMilliseconds
        #expect(first != nil)
        model.markFirstChapterShown(now: Date().addingTimeInterval(60))
        #expect(model.launchMilliseconds == first)
        // The database error screen (no verses) does not count as a launch.
        let broken = ReaderViewModel { throw FakeRepository.Boom() }
        broken.markFirstChapterShown()
        #expect(broken.launchMilliseconds == nil)
    }
}
