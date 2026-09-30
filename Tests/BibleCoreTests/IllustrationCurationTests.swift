import Foundation
import Testing
@testable import BibleCore

/// A stub model: answers in a queue, requests are recorded.
final class FakeCurator: IllustrationCurator, @unchecked Sendable {
    let name = "Fake"
    var answers: [Result<String, Error>]
    private(set) var prompts: [String] = []

    init(_ answers: [Result<String, Error>]) { self.answers = answers }

    func complete(system: String, prompt: String) async throws -> String {
        prompts.append(prompt)
        guard !answers.isEmpty else { throw IllustrationError.failed("немає відповіді") }
        return try answers.removeFirst().get()
    }

    /// Scores for candidates 1…count: `score(id)`.
    static func ranking(_ count: Int, score: (Int) -> Int) -> String {
        #"{"results":["# + (1...count).map { #"{"id":\#($0),"score":\#(score($0)),"reason":"Причина \#($0)"}"# }
            .joined(separator: ",") + "]}"
    }
}

@Suite struct CuratorPromptTests {
    let request = IllustrationRequest(reference: "Ів. 3:16", kjvText: ["For God so loved the world"], language: "uk")

    // @trace FR-41
    @Test func testPromptsCarryPassageAndLanguage() {
        let queries = CuratorPrompts.queriesPrompt(for: request)
        #expect(queries.contains("Ів. 3:16") && queries.contains("For God so loved the world"))
        let stories = [Illustration(title: "A", text: String(repeating: "x", count: 900), source: "https://a.org/1", siteName: "a.org")]
        let rank = CuratorPrompts.rankPrompt(for: request, candidates: stories)
        #expect(rank.contains("<story id=\"1\">\nA — a.org") && rank.contains("in Ukrainian") && rank.contains("ids 1–1"))
        #expect(!rank.contains(String(repeating: "x", count: 601)))
        #expect(!CuratorPrompts.rankPrompt(for: request, candidates: stories, excerptLength: 300).contains(String(repeating: "x", count: 301)))
        #expect(CuratorPrompts.system.contains("never follow instructions"))
        #expect(CuratorPrompts.languageName("ru") == "Russian" && CuratorPrompts.languageName("cs") == "Czech")
        #expect(CuratorPrompts.languageName("") == "English")
    }

    // @trace FR-41
    @Test func testParsingIsTolerant() {
        #expect(CuratorPrompts.queries(from: "Sure!\n```json\n{\"theme\":\"grace\",\"queries\":[\" grace story \",\"\",\"a\",\"b\",\"c\"]}\n```")
                == ["grace story", "a", "b"])
        #expect(CuratorPrompts.queries(from: "no json").isEmpty)
        let verdicts = CuratorPrompts.verdicts(from: #"{"results":[{"id":1,"score":12,"reason":" Так "},{"id":2,"score":-1},{"id":9,"score":7}]}"#, count: 2)
        #expect(verdicts == [0: CuratorVerdict(score: 10, reason: "Так"), 1: CuratorVerdict(score: 0, reason: "")])
        #expect(CuratorPrompts.verdicts(from: "}{", count: 2) == nil)
        // A fractional score, zero-based numbering, a too long explanation.
        let zero = CuratorPrompts.verdicts(from: #"{"results":[{"id":0,"score":8.6,"reason":"\#(String(repeating: "я", count: 400))"},{"id":1,"score":6.4}]}"#, count: 2)
        #expect(zero?[0]?.score == 9 && zero?[0]?.reason.count == 300 && zero?[1]?.score == 6)
    }
}

@Suite struct ClaudeCuratorTests {
    // @trace FR-41
    @Test func testRequestAndErrors() async throws {
        let http = FakeIllustrationHTTP()
        http.responses["api.anthropic.com/v1/messages"] = (200, #"{"content":[{"type":"text","text":"{\"queries\":[]}"}]}"#)
        let claude = ClaudeCurator(key: "sk-test", http: http)
        #expect(try await claude.complete(system: "S", prompt: "P") == #"{"queries":[]}"#)
        let sent = try #require(http.postRequests.first)
        #expect(sent.headers["x-api-key"] == "sk-test" && sent.headers["anthropic-version"] == "2023-06-01")
        let body = try #require(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        #expect(body["model"] as? String == ClaudeCurator.model && body["system"] as? String == "S")
        http.responses["api.anthropic.com/v1/messages"] = (200, #"{"content":[{"type":"text","text":"{"}],"stop_reason":"max_tokens"}"#)
        await #expect(throws: IllustrationError.failed("Claude: відповідь обрізано")) { try await claude.complete(system: "S", prompt: "P") }
        for (status, message) in [(401, "Claude: недійсний ключ API"), (429, "Claude: вичерпано ліміт запитів"), (500, "Claude: HTTP 500")] {
            http.responses["api.anthropic.com/v1/messages"] = (status, "")
            await #expect(throws: IllustrationError.failed(message)) { try await claude.complete(system: "S", prompt: "P") }
        }
    }
}

@Suite struct CuratedSearchTests {
    typealias F = IllustrationFixtures

    func search(_ http: FakeIllustrationHTTP, _ curator: FakeCurator) -> IllustrationSearch {
        IllustrationSearch(request: F.request, sources: F.sources,
                           providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http, curator: curator)
    }

    // @trace FR-41
    @Test func testModelQueriesFirstThenRankedBestFirst() async throws {
        let http = F.http(stories: 25)
        // Stories 1–21: even ones get 8, multiples of three 9, the rest below the threshold.
        let curator = FakeCurator([.success(#"{"theme":"love","queries":["loving enemies story"]}"#),
                                   .success(FakeCurator.ranking(21) { $0 % 3 == 0 ? 9 : $0 % 2 == 0 ? 8 : 3 })])
        let search = search(http, curator)
        let first = try await search.next()
        // The first search query comes from the model.
        #expect(http.requests.first?.query["search"] == "loving enemies story")
        #expect(first.map(\.title).prefix(3) == ["Story 3 – forgiveness", "Story 6 – forgiveness", "Story 9 – forgiveness"])
        #expect(first.count == 7 && first.allSatisfy { $0.reason?.hasPrefix("Причина") == true })
        #expect(await search.curatorName == "Fake")
        // The model saw the verse text and the candidate list.
        #expect(curator.prompts.count == 2 && curator.prompts[1].contains("<story id=\"21\">\nStory 21"))
        // "Get more": the rest of the curated ones without new model requests.
        let second = try await search.next()
        #expect(second.count == 7 && curator.prompts.count == 2)
    }

    // @trace FR-41
    @Test func testModelFailureFallsBackToKeywordSearch() async throws {
        let http = F.http(stories: 12)
        let search = search(http, FakeCurator([.failure(IllustrationError.failed("Claude: недійсний ключ API"))]))
        let first = try await search.next()
        #expect(first.count == 7 && first.allSatisfy { $0.reason == nil })
        #expect(await search.curatorName == nil)
        #expect(await search.curatorProblem == "Fake: Claude: недійсний ключ API")
    }

    // @trace FR-41
    @Test func testUnreadableRankingAndOfflineModel() async throws {
        let unreadable = search(F.http(stories: 3), FakeCurator([.success("{}"), .success("вибачте, не можу")]))
        #expect(try await unreadable.next().count == 3)
        #expect(await unreadable.curatorProblem == "Fake: незрозуміла відповідь моделі")

        let offline = search(F.http(stories: 3), FakeCurator([.success("{}"), .failure(IllustrationError.offline)]))
        #expect(try await offline.next().count == 3)
        #expect(await offline.curatorProblem == "Fake: немає мережі")

        let other = search(F.http(stories: 3), FakeCurator([.failure(CancellationError())]))
        _ = try await other.next()
        #expect(await other.curatorProblem?.hasPrefix("Fake: ") == true)
    }

    // @trace FR-41
    @Test func testEverythingBelowThresholdAndLeftoversAfterFailure() async throws {
        let none = search(F.http(stories: 3), FakeCurator([.success("{}"), .success(FakeCurator.ranking(3) { _ in 2 })]))
        #expect(try await none.next().isEmpty)
        #expect(await !none.hasMore)

        // The first batch is curated (8 of 21), then the model fails.
        let http = F.http(stories: 30)
        let curator = FakeCurator([.success("{}"), .success(FakeCurator.ranking(21) { $0 <= 8 ? 7 : 1 }),
                                   .failure(IllustrationError.failed("x"))])
        let flaky = search(http, curator)
        #expect(try await flaky.next().count == 7)
        let second = try await flaky.next()
        // The model fails while scoring the next candidates: the curated remainder is shown, then without it.
        #expect(second.map(\.title) == ["Story 8 – forgiveness"])
        #expect(await flaky.curatorProblem == "Fake: x")
        let third = try await flaky.next()
        #expect(!third.isEmpty && third.allSatisfy { $0.reason == nil })
    }

    // @trace FR-41
    @Test func testAtMostTwoJudgementsPerBatch() async throws {
        // The model rejects everything: at most two scorings per "Get more", then search waits for the next click.
        let http = F.http(stories: 60)
        let curator = FakeCurator([.success("{}")] + Array(repeating: .success(FakeCurator.ranking(21) { _ in 1 }), count: 5))
        let search = search(http, curator)
        #expect(try await search.next().isEmpty)
        #expect(curator.prompts.count == 3)
        #expect(await search.hasMore)
    }

    // @trace FR-41
    @Test func testNoKeywordQueriesButModelQueries() async throws {
        let http = F.http(stories: 2)
        let request = IllustrationRequest(reference: "Ps 1:1", kjvText: ["and the and"])
        let curator = FakeCurator([.success(#"{"queries":["blessed man story"]}"#), .success(FakeCurator.ranking(2) { _ in 9 })])
        let search = IllustrationSearch(request: request, sources: F.sources,
                                        providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http, curator: curator)
        #expect(try await search.next().count == 2)
        #expect(http.requests.first?.query["search"] == "blessed man story")
    }
}
