import Foundation
import Testing
@testable import BibleCore

/// Мережа з фікстур: відповідь за хостом і шляхом; журнал запитів — щоб перевірити, куди ходили.
final class FakeIllustrationHTTP: IllustrationHTTP, @unchecked Sendable {
    var responses: [String: (Int, String)] = [:]
    /// Дописи WordPress за номером: `/wp-json/wp/v2/posts?include=…` збирає з них відповідь.
    var posts: [Int: String] = [:]
    var postsStatus = 200
    var error: IllustrationError?
    private(set) var requests: [(host: String, path: String, query: [String: String], headers: [String: String])] = []

    func get(host: String, path: String, query: [(String, String)], headers: [String: String]) async throws -> (status: Int, body: Data) {
        let items = Dictionary(query, uniquingKeysWith: { a, _ in a })
        requests.append((host, path, items, headers))
        if let error { throw error }
        if path == "/wp-json/wp/v2/posts", let include = items["include"] {
            let bodies = include.split(separator: ",").compactMap { Int($0).flatMap { posts[$0] } }
            return (postsStatus, Data(("[" + bodies.joined(separator: ",") + "]").utf8))
        }
        let page = items["page"] ?? items["gsroffset"] ?? items["offset"] ?? ""
        let (status, body) = responses["\(host)\(path)#\(page)"] ?? responses["\(host)\(path)"] ?? (404, "")
        return (status, Data(body.utf8))
    }
}

enum IllustrationFixtures {
    static let sources = try! IllustrationSources.load(from: Data("""
    {"allow": ["example.org", "en.wikipedia.org"], "block": ["catholic.com"],
     "wordpress": [{"name": "Example", "host": "www.example.org"}]}
    """.utf8))

    static func wpSearch(_ ids: ClosedRange<Int>, host: String = "www.example.org") -> String {
        "[" + ids.map { id in
            #"{"id":\#(id),"title":"Story \#(id)","url":"https:\/\/\#(host)\/story-\#(id)\/","subtype":"post","_links":{"self":[{"href":"https:\/\/\#(host)\/wp-json\/wp\/v2\/posts\/\#(id)"}]}}"#
        }.joined(separator: ",") + "]"
    }

    static func wpPost(_ id: Int, text: String = "Hudson Taylor forgave the robbers in Ningbo, 1857.") -> String {
        #"{"id":\#(id),"title":{"rendered":"Story \#(id) &#8211; forgiveness"},"content":{"rendered":"<p>\#(text)</p><script>x()</script><p>Second &amp; last.</p>"},"link":"https:\/\/www.example.org\/story-\#(id)\/","date":"2020-04-16T08:00:03"}"#
    }

    static let request = IllustrationRequest(reference: "Mt 5:44", kjvText: [
        "But I say unto you, Love your enemies, bless them that curse you, do good to them that hate you, and pray for them which despitefully use you, and persecute you;",
    ])

    /// Сайт з `count` історіями на сторінках по 10.
    static func http(stories count: Int) -> FakeIllustrationHTTP {
        let http = FakeIllustrationHTTP()
        for page in 1...max(1, (count + 9) / 10) {
            let first = (page - 1) * 10 + 1, last = min(page * 10, count)
            http.responses["www.example.org/wp-json/wp/v2/search#\(page)"] = first <= last ? (200, wpSearch(first...last)) : (200, "[]")
        }
        http.responses["www.example.org/wp-json/wp/v2/search#\((count + 9) / 10 + 1)"] = (400, #"{"code":"rest_post_invalid_page_number"}"#)
        for id in 1...max(1, count) { http.posts[id] = wpPost(id) }
        http.responses["en.wikipedia.org/w/api.php"] = (200, #"{"batchcomplete":true}"#)
        return http
    }
}

@Suite struct IllustrationTests {
    typealias F = IllustrationFixtures

    // @trace FR-33
    @Test func testKeywordsSkipStopWordsAndRankByFrequency() {
        #expect(IllustrationQuery.keywords(from: F.request.kjvText) == ["love", "enemies", "bless", "curse"])
        #expect(IllustrationQuery.queries(from: F.request.kjvText) == ["love enemies bless", "love enemies", "love", "enemies", "bless", "curse"])
        #expect(IllustrationQuery.queries(from: ["and the"]).isEmpty)
    }

    // @trace FR-33
    @Test func testFirstBatchIsSevenThenMore() async throws {
        let http = F.http(stories: 12)
        let search = IllustrationSearch(request: F.request, sources: F.sources,
                                        providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http)
        let first = try await search.next()
        #expect(first.count == 7)
        #expect(first[0].title == "Story 1 – forgiveness")
        #expect(first[0].text == "Hudson Taylor forgave the robbers in Ningbo, 1857.\n\nSecond & last.")
        #expect(first[0].date == "2020-04-16")
        #expect(await search.hasMore)
        // «Отримати ще»: решта 5 без повторів.
        let second = try await search.next()
        #expect(second.map(\.title) == (8...12).map { "Story \($0) – forgiveness" })
        #expect(Set(first.map(\.id)).isDisjoint(with: second.map(\.id)))
    }

    // @trace FR-33
    @Test func testFewerThanSevenWhenNothingMore() async throws {
        let http = F.http(stories: 3)
        let search = IllustrationSearch(request: F.request, sources: F.sources,
                                        providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http)
        #expect(try await search.next().count == 3)
        #expect(try await search.next().isEmpty)
        #expect(await !search.hasMore)
    }

    // @trace FR-33
    @Test func testOfflineAndFailureAreDistinct() async {
        let http = F.http(stories: 3)
        http.error = .offline
        let search = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: http)
        await #expect(throws: IllustrationError.offline) { try await search.next() }
        let broken = F.http(stories: 3)
        broken.responses["www.example.org/wp-json/wp/v2/search#1"] = (500, "")
        let failing = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: broken)
        await #expect(throws: IllustrationError.failed("www.example.org: HTTP 500")) { try await failing.next() }
    }

    // @trace FR-35
    @Test func testNoRequestsForEmptyQuery() async throws {
        let http = F.http(stories: 3)
        let search = IllustrationSearch(request: IllustrationRequest(reference: "x", kjvText: ["and the of"]), sources: F.sources,
                                        providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http)
        #expect(try await search.next().isEmpty)
        #expect(http.requests.isEmpty)
    }
}

extension IllustrationTests {
    // @trace FR-34
    @Test func testAllowlistAndBlocklist() {
        let sources = IllustrationSources(allow: ["example.org", "bible.org"], block: ["catholic.com", "bad.example.org"], wordpress: [])
        #expect(sources.isAllowed("https://www.example.org/a"))
        #expect(sources.isAllowed("https://blog.example.org/a"))
        #expect(!sources.isAllowed("http://example.org/a"))           // лише https
        #expect(!sources.isAllowed("https://notexample.org/a"))       // не піддомен
        #expect(!sources.isAllowed("https://bad.example.org/a"))      // blocklist перемагає
        #expect(!sources.isAllowed("https://www.catholic.com/a"))
        #expect(!sources.isAllowed("example.org/a"))
        #expect(!sources.isAllowed("https:///a"))
    }

    // @trace FR-34
    @Test func testBundledSourcesMatchTheDoc() throws {
        let sources = try IllustrationSources.bundled
        #expect(sources.allow.count == 18)
        #expect(sources.block.contains("vatican.va") && sources.block.contains("pravoslavie.ru"))
        #expect(Set(sources.allow).isDisjoint(with: sources.block))
        for site in sources.wordpress { #expect(sources.isAllowed("https://\(site.host)/"), "\(site.host)") }
    }

    // @trace FR-34
    @Test func testStoryOutsideAllowlistIsDropped() async throws {
        let http = F.http(stories: 2)
        // Допис посилається на чужий домен — історію відкинуто.
        http.posts[2] = F.wpPost(2).replacingOccurrences(of: "www.example.org", with: "www.catholic.com")
        let search = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: http)
        #expect(try await search.next().map(\.title) == ["Story 1 – forgiveness"])
    }

    // @trace FR-34
    @Test func testWordPressIgnoresForeignApiLinks() {
        #expect(WordPressAdapter.postID(of: "https://www.example.org/wp-json/wp/v2/posts/7", host: "www.example.org") == 7)
        #expect(WordPressAdapter.postID(of: "https://evil.com/wp-json/wp/v2/posts/7", host: "www.example.org") == nil)
        #expect(WordPressAdapter.postID(of: "https://www.example.org/wp-json/wp/v2/pages/7", host: "www.example.org") == nil)
    }

    // @trace FR-33
    @Test func testOneFailingSourceDoesNotStopOthers() async throws {
        // Сайт обмежив частоту (403) на текстах — Вікіпедія все одно дає історії; помилки не показуємо.
        let http = F.http(stories: 3)
        http.postsStatus = 403
        http.responses["en.wikipedia.org/w/api.php"] = (200, Self.wikipedia)
        let search = IllustrationSearch(request: F.request, sources: F.sources,
                                        providers: IllustrationSearch.providers(sources: F.sources, braveKey: nil), http: http)
        #expect(try await search.next().map(\.title) == ["General Butt Naked"])
        // Лише зламане джерело — помилка з поясненням.
        let alone = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: http)
        await #expect(throws: IllustrationError.failed("www.example.org: HTTP 403")) { try await alone.next() }
        // Зіпсована відповідь (не JSON) — теж помилка джерела, а не падіння.
        http.responses["www.example.org/wp-json/wp/v2/search#1"] = (200, "<html>")
        let garbled = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: http)
        await #expect(throws: (any Error).self) { try await garbled.next() }
    }
}

extension IllustrationTests {
    static let wikipedia = #"""
    {"query":{"pages":[
      {"index":2,"title":"General Butt Naked","extract":"Joshua Milton Blahyi is a Liberian former warlord who became an evangelist.","fullurl":"https://en.wikipedia.org/wiki/General_Butt_Naked",
       "categories":[{"title":"Category:1971 births"},{"title":"Category:Liberian evangelicals"}]},
      {"index":1,"title":"Matthew 5:44","extract":"Verse of the Sermon on the Mount.","fullurl":"https://en.wikipedia.org/wiki/Matthew_5:44",
       "categories":[{"title":"Category:Matthew 5"}]},
      {"index":3,"title":"Maximilian Kolbe","extract":"Polish friar who died in Auschwitz.","fullurl":"https://en.wikipedia.org/wiki/Maximilian_Kolbe",
       "categories":[{"title":"Category:1894 births"},{"title":"Category:Roman Catholic saints"}]},
      {"index":4,"title":"Elisabeth","extract":"Grand duchess.","fullurl":"https://en.wikipedia.org/wiki/Elisabeth",
       "categories":[{"title":"Category:1918 deaths"},{"title":"Category:Russian Orthodox Church"}]}
    ]}}
    """#

    // @trace FR-34
    @Test func testWikipediaKeepsOnlyNonCatholicNonOrthodoxBiographies() async throws {
        let http = FakeIllustrationHTTP()
        http.responses["en.wikipedia.org/w/api.php"] = (200, Self.wikipedia)
        let page = try await WikipediaAdapter().page("enemies", page: 1, http: http)
        #expect(page.stories.map(\.title) == ["General Butt Naked"])
        #expect(page.stories[0].siteName == "Wikipedia" && !page.stories[0].isExcerpt)
        #expect(!page.hasMore)  // 4 статті з 10 — сторінок більше немає
        let query = try #require(http.requests.first?.query)
        #expect(query["gsrsearch"]?.hasPrefix("enemies Christian (missionary") == true)
        #expect(query["gsroffset"] == "0")
        #expect(WikipediaAdapter.isExcluded(["Category:Popes"]) && WikipediaAdapter.isExcluded(["Category:Jesuit missionaries"]))
        #expect(!WikipediaAdapter.isExcluded(["Category:Baptist missionaries", "Category:Saintsbury family"]))
    }

    // @trace FR-33
    @Test func testBraveSearchesAllowlistWithUserKey() async throws {
        let http = FakeIllustrationHTTP()
        http.responses["api.search.brave.com/res/v1/web/search"] = (200, #"""
        {"web":{"results":[
          {"title":"<strong>Loving</strong> your enemies","url":"https://www.desiringgod.org/articles/love","description":"Jim Elliot was killed in 1956 &amp; his widow returned.","page_age":"2019-05-01T00:00:00"},
          {"title":"No text","url":"https://www.founders.org/x","description":""}
        ]}}
        """#)
        let brave = BraveAdapter(key: "k-123", sites: ["desiringgod.org", "founders.org"])
        let page = try await brave.page("love enemies", page: 1, http: http)
        #expect(page.stories.map(\.title) == ["Loving your enemies"])
        #expect(page.stories[0].text == "Jim Elliot was killed in 1956 & his widow returned.")
        #expect(page.stories[0].isExcerpt && page.stories[0].siteName == "desiringgod.org" && page.stories[0].date == "2019-05-01")
        #expect(!page.hasMore)
        let request = try #require(http.requests.first)
        #expect(request.headers["X-Subscription-Token"] == "k-123")
        #expect(request.query["q"] == "love enemies (site:desiringgod.org OR site:founders.org)")
        for (status, message) in [(401, "Brave Search: недійсний ключ API"), (429, "Brave Search: вичерпано ліміт запитів"), (500, "Brave Search: HTTP 500")] {
            http.responses["api.search.brave.com/res/v1/web/search"] = (status, "")
            await #expect(throws: IllustrationError.failed(message)) { try await brave.page("x", page: 1, http: http) }
        }
    }

    // @trace FR-33
    @Test func testProvidersWithoutAndWithKey() {
        let without = IllustrationSearch.providers(sources: F.sources, braveKey: nil)
        #expect(without.count == 2)
        #expect(IllustrationSearch.providers(sources: F.sources, braveKey: "").count == 2)
        let with = IllustrationSearch.providers(sources: F.sources, braveKey: "k")
        let brave = try? #require(with.last as? BraveAdapter)
        #expect(brave?.sites == ["example.org"])  // Вікіпедію Brave не шукає
    }
}

extension IllustrationTests {
    // @trace FR-33
    @Test func testExcerptCutsLongTextAtParagraph() {
        let paragraph = String(repeating: "word ", count: 180)  // ~900 символів
        let (text, truncated) = IllustrationExcerpt.cut(paragraph + "\n\n" + paragraph + "\n\n" + paragraph)
        #expect(truncated && text.hasSuffix(" …") && text.count <= IllustrationExcerpt.limit + 2)
        #expect(IllustrationExcerpt.cut("short").truncated == false)
        let noBreaks = String(repeating: "a", count: 2000)
        #expect(IllustrationExcerpt.cut(noBreaks).text.count == IllustrationExcerpt.limit + 1)
        let sentences = String(repeating: "Hudson Taylor sailed. ", count: 100)
        #expect(IllustrationExcerpt.cut(sentences).text.hasSuffix("sailed. …"))
    }

    // @trace FR-33
    @Test func testHTMLTextAndEntities() {
        #expect(HTMLText.plain("<h2>A</h2><p>B&nbsp;&nbsp;C<br>D</p><style>p{}</style>") == "A\n\nB C\n\nD")
        #expect(HTMLText.decodeEntities("&#8217;&#x2019;&rsquo;&unknown; & &#99999999;") == "’’’&unknown; & &#99999999;")
    }

    // @trace FR-33
    @Test func testCopyTextCarriesSource() {
        let story = Illustration(title: "T", text: "Body", source: "https://www.imb.org/x", siteName: "IMB")
        #expect(story.copyText == "T\n\nBody\n\nДжерело: IMB, https://www.imb.org/x")
    }
}

@MainActor @Suite struct IllustrationRequestTests {
    // @trace FR-33
    @Test func testRequestUsesKJVTextAndLocalReference() {
        let model = ReaderViewModel { FakeRepository() }
        model.translation = .synodal
        model.open(Location(book: 43, chapter: 3))
        let request = model.illustrationRequest(for: [3, 1, 2])
        #expect(request?.reference == "От Иоанна 3:1-3")
        #expect(request?.kjvText == ["kjv 43:3:1", "kjv 43:3:2", "kjv 43:3:3"])
        #expect(model.illustrationRequest(for: []) == nil)
        #expect(ReaderViewModel { throw FakeRepository.Boom() }.illustrationRequest(for: [1]) == nil)
    }
}

extension IllustrationTests {
    // @trace FR-34
    @Test func testWikipediaSparsePagesAndFullPage() async throws {
        let http = FakeIllustrationHTTP()
        // Без index і без категорій — не біографія; повна сторінка (10) — є наступна.
        let pages = (1...10).map { #"{"title":"P\#($0)","extract":"x","fullurl":"https://en.wikipedia.org/wiki/P\#($0)"}"# }
        http.responses["en.wikipedia.org/w/api.php"] = (200, #"{"query":{"pages":["# + pages.joined(separator: ",") + "]}}")
        let page = try await WikipediaAdapter().page("x", page: 2, http: http)
        #expect(page.stories.isEmpty && page.hasMore)
        #expect(http.requests.first?.query["gsroffset"] == "10")
        http.responses["en.wikipedia.org/w/api.php"] = (200, "{}")
        #expect(try await WikipediaAdapter().page("x", page: 1, http: http).stories.isEmpty)
        http.responses["en.wikipedia.org/w/api.php"] = (503, "")
        await #expect(throws: IllustrationError.failed("en.wikipedia.org: HTTP 503")) { try await WikipediaAdapter().page("x", page: 1, http: http) }
    }

    // @trace FR-33
    @Test func testBraveFullPageAndEmptyResponse() async throws {
        let http = FakeIllustrationHTTP()
        let results = (1...20).map { #"{"title":"T\#($0)","url":"https://www.imb.org/\#($0)"}"# }
        http.responses["api.search.brave.com/res/v1/web/search"] = (200, #"{"web":{"results":["# + results.joined(separator: ",") + "]}}")
        let brave = BraveAdapter(key: "k", sites: ["imb.org"])
        let full = try await brave.page("x", page: 1, http: http)
        #expect(full.stories.isEmpty && full.hasMore)          // без опису — картки немає, але сторінка повна
        #expect(try await !brave.page("x", page: 10, http: http).hasMore)  // Brave: не більше 10 сторінок
        http.responses["api.search.brave.com/res/v1/web/search"] = (200, "{}")
        #expect(try await brave.page("x", page: 1, http: http).stories.isEmpty)
    }
}

extension IllustrationTests {
    // @trace FR-33
    @Test func testKeywordsRankRepeatedWordsFirst() {
        #expect(IllustrationQuery.keywords(from: ["faith upon grace", "grace and faith, grace"]) == ["grace", "faith"])
    }

    // @trace FR-33
    @Test func testRelevantStoriesComeFirst() async throws {
        let http = F.http(stories: 3)
        http.posts[2] = F.wpPost(2, text: "Bless those who curse you.")
        http.posts[3] =
            #"{"id":3,"title":{"rendered":"Love your enemies"},"content":{"rendered":"<p>They chose to love their enemies.</p>"},"link":"https://www.example.org/story-3/"}"#
        let search = IllustrationSearch(request: F.request, sources: F.sources, providers: [WordPressAdapter(site: F.sources.wordpress[0])], http: http)
        // Ключові слова в заголовку важать удвічі; без збігів — в кінці, у порядку сайту.
        #expect(try await search.next().map(\.title) == ["Love your enemies", "Story 2 – forgiveness", "Story 1 – forgiveness"])
    }

    // @trace FR-33
    @Test func testWordPressSkipsBrokenHitsAndPosts() async throws {
        let http = FakeIllustrationHTTP()
        http.responses["www.example.org/wp-json/wp/v2/search#1"] = (200, #"""
        [{"title":"No links","url":"https://www.example.org/a","subtype":"post"},
         {"title":"Page","url":"https://www.example.org/p","subtype":"page","_links":{"self":[{"href":"https://www.example.org/wp-json/wp/v2/pages/1"}]}},
         {"title":"Gone","url":"https://www.example.org/g","subtype":"post","_links":{"self":[{"href":"https://www.example.org/wp-json/wp/v2/posts/8"}]}},
         {"title":"Empty","url":"https://www.example.org/e","subtype":"post","_links":{"self":[{"href":"https://www.example.org/wp-json/wp/v2/posts/9"}]}}]
        """#)
        // Допису 8 сайт не віддав, 9 — порожній.
        http.posts[9] = #"{"id":9,"title":{"rendered":"E"},"content":{"rendered":"<p> </p>"},"link":"https://www.example.org/e"}"#
        let adapter = WordPressAdapter(site: F.sources.wordpress[0])
        let page = try await adapter.page("x", page: 1, http: http)
        #expect(page.stories.isEmpty && !page.hasMore)
        http.responses["www.example.org/wp-json/wp/v2/search#2"] = (400, "")
        #expect(try await adapter.page("x", page: 2, http: http).stories.isEmpty)
    }
}

@MainActor extension IllustrationRequestTests {
    // @trace FR-33
    @Test func testNoKJVTextGivesNoRequest() {
        let repository = FakeRepository()
        let model = ReaderViewModel { repository }
        repository.failNextVerses = true
        #expect(model.illustrationRequest(for: [1]) == nil)
    }
}
