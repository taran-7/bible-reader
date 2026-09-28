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
        // Найважча частина запуску в BibleCore: відкриття бази й перший розділ.
        // Найкращий із трьох: паралельні тести інколи забирають процесор, а ми міряємо код, а не навантаження.
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
        // Екран помилки бази (віршів немає) не рахується запуском.
        let broken = ReaderViewModel { throw FakeRepository.Boom() }
        broken.markFirstChapterShown()
        #expect(broken.launchMilliseconds == nil)
    }
}
