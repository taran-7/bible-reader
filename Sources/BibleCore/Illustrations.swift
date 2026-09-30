import Foundation

// Illustrations (FR-33…FR-35, PRD 6.17): true stories for the selected verses from Protestant sites, Wikipedia, Brave.
// Live search on click, no local index and no storage: network only in `IllustrationNetwork`,
// here: query building, response parsing, allowlist, deduplication and batches of 7.

/// Selected verses for the illustrations window: the reference in the screen language, the text in KJV (English search)
/// and the on-screen translation's language, the target of the card's "Translate" button.
public struct IllustrationRequest: Codable, Hashable, Sendable {
    public let reference: String
    public let kjvText: [String]
    /// The language code (`uk`, `ru`, `cs`, `en`…) of the on-screen Bible translation.
    public let language: String

    public init(reference: String, kjvText: [String], language: String = "en") {
        self.reference = reference
        self.kjvText = kjvText
        self.language = language
    }

    private enum CodingKeys: String, CodingKey { case reference, kjvText, language }

    /// A window restored by macOS from an old version has no language: English.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(reference: try container.decode(String.self, forKey: .reference),
                  kjvText: try container.decode([String].self, forKey: .kjvText),
                  language: try container.decodeIfPresent(String.self, forKey: .language) ?? "en")
    }

    /// The language to translate stories into; `nil` means English, nothing to translate.
    public var translationTarget: String? { language == "en" ? nil : language }
}

/// A story: title, page text, source. Nothing is stored, only "Copy".
public struct Illustration: Identifiable, Hashable, Sendable {
    public let title: String
    public let text: String
    public let source: String
    public let siteName: String
    public let date: String?
    /// Only the beginning or an excerpt is shown: the card has a "Read on site" link.
    public let isExcerpt: Bool
    /// The model's "Why this story" in the on-screen translation's language (FR-41); `nil` means no model curation.
    public var reason: String?
    public var id: String { source }

    public init(title: String, text: String, source: String, siteName: String, date: String? = nil, isExcerpt: Bool = false,
                reason: String? = nil) {
        self.reason = reason
        self.title = title
        self.text = text
        self.source = source
        self.siteName = siteName
        self.date = date
        self.isExcerpt = isExcerpt
    }

    /// Clipboard text: the story together with its source, so it can be pasted into a note.
    public var copyText: String { copyText(title: title, text: text) }

    /// What is currently on the card (original or translation) and the source, always an English link.
    public func copyText(title: String, text: String) -> String {
        "\(title)\n\n\(text)\n\nДжерело: \(siteName), \(source)"
    }
}

/// The source list (`Resources/illustration-sources.json`, [illustration-sources.md](docs/product-specs/illustration-sources.md)).
public struct IllustrationSources: Decodable, Sendable {
    public struct Site: Decodable, Hashable, Sendable {
        public let name: String
        public let host: String
    }

    public let allow: [String]
    public let block: [String]
    /// Sites with WordPress REST search (full text). The rest of the allowlist, closed to bots, is searched by Brave with `site:`.
    public let wordpress: [Site]

    public static func load(from data: Data) throws -> IllustrationSources {
        try JSONDecoder().decode(IllustrationSources.self, from: data)
    }

    public static var bundled: IllustrationSources {
        get throws {
            try load(from: Data(contentsOf: Bundle.module.url(forResource: "illustration-sources", withExtension: "json")!))
        }
    }

    /// The host without `www.`, lowercase.
    static func bare(_ host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }

    private static func matches(_ host: String, _ domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    /// FR-34: a story is taken only from an allowlisted domain; the blocklist is checked first and wins.
    public func isAllowed(_ address: String) -> Bool {
        // Secure addresses only (https scheme).
        guard let (scheme, host) = Self.parse(address), scheme == "https" else { return false }
        if block.contains(where: { Self.matches(host, $0) }) { return false }
        return allow.contains { Self.matches(host, $0) }
    }
}

/// English keywords from the KJV text: no stop words, most frequent first.
public enum IllustrationQuery {
    static let stopWords: Set<String> = [
        "the", "and", "that", "for", "unto", "with", "his", "her", "him", "they", "them", "their", "thee", "thou", "thy",
        "thine", "shall", "have", "hath", "had", "not", "but", "which", "who", "whom", "whose", "this", "these", "those",
        "from", "into", "upon", "there", "then", "than", "when", "what", "were", "was", "are", "all", "also", "even",
        "said", "saith", "say", "will", "would", "should", "may", "might", "let", "one", "out", "because", "therefore",
        "every", "any", "being", "been", "ye", "you", "your", "our", "ours", "hast", "art", "doth", "did", "come",
        "came", "went", "made", "make", "things", "thing", "over", "before", "after", "about", "such", "own", "yea",
    ]

    public static func keywords(from texts: [String], limit: Int = 4) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for text in texts {
            let words = text.lowercased().split { !$0.isLetter }.map(String.init)
            for word in words where word.count >= 4 && !stopWords.contains(word) {
                if counts[word] == nil { order.append(word) }
                counts[word, default: 0] += 1
            }
        }
        // Stable: more frequent first, ties in text order.
        let ranked = order.enumerated().sorted { a, b in
            let (ca, cb) = (counts[a.element]!, counts[b.element]!)
            return ca != cb ? ca > cb : a.offset < b.offset
        }
        return ranked.prefix(limit).map(\.element)
    }

    /// Queries from narrower to broader: WordPress searches for all words together, so then pairs and single words.
    public static func queries(from texts: [String]) -> [String] {
        let words = keywords(from: texts)
        var result: [String] = []
        func add(_ query: String) { if !query.isEmpty, !result.contains(query) { result.append(query) } }
        add(words.prefix(3).joined(separator: " "))
        if words.count >= 2 { add(words.prefix(2).joined(separator: " ")) }
        for word in words { add(word) }
        return result
    }
}

/// The illustration network behind a protocol: tests plug in fixtures, the app `IllustrationNetwork`.
public protocol IllustrationHTTP: Sendable {
    /// GET at a secure address `<host><path>?<query>` with headers; returns the response code and body.
    func get(host: String, path: String, query: [(String, String)], headers: [String: String]) async throws -> (status: Int, body: Data)
    /// POST JSON at a secure address: for the API of the model that curates stories (FR-41).
    func post(host: String, path: String, headers: [String: String], body: Data) async throws -> (status: Int, body: Data)
}

public enum IllustrationError: Error, Equatable, Sendable {
    /// No network: the message «Немає підключення до мережі» (No network connection).
    case offline
    case failed(String)
}

/// A page from one source: stories after filters, and whether the source has a next page.
public struct IllustrationPage: Sendable {
    public let stories: [Illustration]
    public let hasMore: Bool

    public init(stories: [Illustration], hasMore: Bool) {
        self.stories = stories
        self.hasMore = hasMore
    }
}

/// A story source: a page of results for a query.
public protocol IllustrationProvider: Sendable {
    func page(_ query: String, page: Int, http: IllustrationHTTP) async throws -> IllustrationPage
}

/// Card text for copyrighted articles: the beginning and a "Read on site" link.
public enum IllustrationExcerpt {
    public static let limit = 1500

    /// Cuts at a paragraph or sentence boundary in the second half of the limit; `truncated` means the text was shortened.
    public static func cut(_ text: String, limit: Int = limit) -> (text: String, truncated: Bool) {
        guard text.count > limit else { return (text, false) }
        let head = String(text.prefix(limit))
        let minimum = head.index(head.startIndex, offsetBy: limit / 2)
        if let range = head.range(of: "\n\n", options: .backwards), range.lowerBound > minimum {
            return (String(head[..<range.lowerBound]) + " …", true)
        }
        if let range = head.range(of: ". ", options: .backwards), range.lowerBound > minimum {
            return (String(head[...range.lowerBound]) + " …", true)
        }
        return (head + "…", true)
    }
}

/// WordPress REST search (`/wp-json/wp/v2/search`) and post text (`/wp-json/wp/v2/posts/<id>`).
public struct WordPressAdapter: IllustrationProvider {
    public let site: IllustrationSources.Site
    static let pageSize = 10

    public init(site: IllustrationSources.Site) {
        self.site = site
    }

    /// A found post before its text is loaded.
    struct Hit: Hashable, Sendable {
        let title: String
        let url: String
        /// The post id from the API address `/wp-json/wp/v2/posts/<id>` of the same site.
        let id: Int
    }

    private struct SearchItem: Decodable {
        struct Links: Decodable {
            struct Link: Decodable { let href: String }
            let links: [Link]
            enum CodingKeys: String, CodingKey { case links = "self" }
        }
        let title: String
        let url: String
        let subtype: String?
        let _links: Links?
    }

    private struct Post: Decodable {
        struct Rendered: Decodable { let rendered: String }
        let id: Int
        let title: Rendered
        let content: Rendered
        let link: String
        let date: String?
    }

    public func page(_ query: String, page: Int, http: IllustrationHTTP) async throws -> IllustrationPage {
        let hits = try await search(query, page: page, http: http)
        return IllustrationPage(stories: try await illustrations(hits, http: http), hasMore: hits.count == Self.pageSize)
    }

    /// A page of results; an empty array means no more pages (WordPress gives 400 for an extra page).
    func search(_ text: String, page: Int, http: IllustrationHTTP) async throws -> [Hit] {
        let (status, body) = try await http.get(host: site.host, path: "/wp-json/wp/v2/search", query: [
            ("search", text), ("type", "post"), ("subtype", "post"),
            ("per_page", "\(Self.pageSize)"), ("page", "\(page)"),
        ], headers: [:])
        if status == 400 { return [] }
        guard status == 200 else { throw IllustrationError.failed("\(site.host): HTTP \(status)") }
        let items = try JSONDecoder().decode([SearchItem].self, from: body)
        var hits: [Hit] = []
        for item in items where item.subtype == nil || item.subtype == "post" {
            guard let href = item._links?.links.first?.href, let id = Self.postID(of: href, host: site.host) else { continue }
            hits.append(Hit(title: HTMLText.plain(item.title), url: item.url, id: id))
        }
        return hits
    }

    /// Texts of all posts on the page in one request (`include=`), in search order: sites rate-limit requests
    /// (Christianity Today answered 403 to a dozen separate ones). The first ≤ 1500 characters: copyright.
    func illustrations(_ hits: [Hit], http: IllustrationHTTP) async throws -> [Illustration] {
        guard !hits.isEmpty else { return [] }
        let (status, body) = try await http.get(host: site.host, path: "/wp-json/wp/v2/posts", query: [
            ("include", hits.map { "\($0.id)" }.joined(separator: ",")), ("per_page", "\(hits.count)"),
            ("_fields", "id,title,content,link,date"),
        ], headers: [:])
        guard status == 200 else { throw IllustrationError.failed("\(site.host): HTTP \(status)") }
        let posts = Dictionary((try JSONDecoder().decode([Post].self, from: body)).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var stories: [Illustration] = []
        for hit in hits {
            guard let post = posts[hit.id] else { continue }
            let text = HTMLText.plain(post.content.rendered)
            guard !text.isEmpty else { continue }
            let excerpt = IllustrationExcerpt.cut(text)
            stories.append(Illustration(title: HTMLText.plain(post.title.rendered), text: excerpt.text, source: post.link,
                                        siteName: site.name, date: post.date.map { String($0.prefix(10)) }, isExcerpt: excerpt.truncated))
        }
        return stories
    }

    /// The post id from the address `…/wp-json/wp/v2/posts/<id>` of the same site; a foreign host or another type gives `nil`.
    static func postID(of href: String, host: String) -> Int? {
        guard let hrefHost = IllustrationSources.host(of: href), hrefHost == IllustrationSources.bare(host),
              let range = href.range(of: "/wp-json/wp/v2/posts/") else { return nil }
        return Int(href[range.upperBound...])
    }
}

/// Wikipedia (CC BY-SA): only biographies of real people (categories "… births/deaths") and no Catholic
/// or Orthodox topics (saints, popes, monks etc., owner decision 2026-09-28); the text is the article intro.
public struct WikipediaAdapter: IllustrationProvider {
    public static let host = "en.wikipedia.org"
    static let pageSize = 10
    /// A query hint: life stories of Christians, not verse commentary.
    static let hint = "Christian (missionary OR evangelist OR pastor OR preacher OR conversion OR revival)"
    static let excludedWords = [
        "catholic", "orthodox", "pope", "popes", "papal", "saint", "saints", "cardinal", "cardinals", "monk", "monks",
        "nun", "nuns", "monastery", "monasteries", "monastic", "patriarch", "patriarchs", "jesuit", "jesuits", "franciscan",
        "franciscans", "dominican", "benedictine", "beatified", "beatifications", "canonized", "canonizations", "venerated",
    ]

    public init() {}

    private struct Response: Decodable {
        struct Query: Decodable { let pages: [Page] }
        struct Page: Decodable {
            struct Category: Decodable { let title: String }
            let index: Int?
            let title: String
            let extract: String?
            let fullurl: String?
            let categories: [Category]?
        }
        let query: Query?
    }

    /// A person: has a "… births" or "… deaths" category.
    static func isPerson(_ categories: [String]) -> Bool {
        categories.contains { $0.hasSuffix(" births") || $0.hasSuffix(" deaths") }
    }

    /// A Catholic or Orthodox topic: a category name contains one of the `excludedWords`.
    static func isExcluded(_ categories: [String]) -> Bool {
        let excluded = Set(excludedWords)
        return categories.contains { category in
            category.lowercased().split { !$0.isLetter }.contains { excluded.contains(String($0)) }
        }
    }

    public func page(_ query: String, page: Int, http: IllustrationHTTP) async throws -> IllustrationPage {
        let (status, body) = try await http.get(host: Self.host, path: "/w/api.php", query: [
            ("action", "query"), ("format", "json"), ("formatversion", "2"),
            ("generator", "search"), ("gsrsearch", "\(query) \(Self.hint)"),
            ("gsrlimit", "\(Self.pageSize)"), ("gsroffset", "\((page - 1) * Self.pageSize)"),
            ("prop", "extracts|categories|info"), ("exintro", "1"), ("explaintext", "1"), ("exlimit", "max"),
            ("cllimit", "max"), ("clshow", "!hidden"), ("inprop", "url"),
        ], headers: [:])
        guard status == 200 else { throw IllustrationError.failed("\(Self.host): HTTP \(status)") }
        let pages = try JSONDecoder().decode(Response.self, from: body).query?.pages ?? []
        var stories: [Illustration] = []
        for page in pages.sorted(by: { ($0.index ?? 0) < ($1.index ?? 0) }) {
            let categories = (page.categories ?? []).map(\.title)
            guard let url = page.fullurl, let extract = page.extract, !extract.isEmpty,
                  Self.isPerson(categories), !Self.isExcluded(categories) else { continue }
            stories.append(Illustration(title: page.title, text: extract, source: url, siteName: "Wikipedia"))
        }
        // Filtered-out articles do not mean the end: there is a next page if this one was full.
        return IllustrationPage(stories: stories, hasMore: pages.count == Self.pageSize)
    }
}

/// The Brave Search API (the user's key): a `site:` search over the whole allowlist, including sites
/// closed to bots. Pages are not opened: only the title, the search engine snippet and the link.
public struct BraveAdapter: IllustrationProvider {
    public static let host = "api.search.brave.com"
    public let key: String
    public let sites: [String]
    static let pageSize = 20
    /// How many `site:` per query: Brave's limit is 400 characters and 50 words including the keywords.
    public static let sitesPerQuery = 5
    /// Brave returns up to 10 pages (offset 0…9).
    static let maxPages = 10

    public init(key: String, sites: [String]) {
        self.key = key
        self.sites = sites
    }

    private struct Response: Decodable {
        struct Web: Decodable { let results: [Result] }
        struct Result: Decodable {
            let title: String
            let url: String
            let description: String?
            let page_age: String?
        }
        let web: Web?
    }

    public func page(_ query: String, page: Int, http: IllustrationHTTP) async throws -> IllustrationPage {
        let scope = sites.map { "site:\($0)" }.joined(separator: " OR ")
        let (status, body) = try await http.get(host: Self.host, path: "/res/v1/web/search", query: [
            ("q", "\(query) (\(scope))"), ("count", "\(Self.pageSize)"), ("offset", "\(page - 1)"),
            ("safesearch", "strict"), ("search_lang", "en"),
        ], headers: ["X-Subscription-Token": key, "Accept": "application/json"])
        switch status {
        case 200: break
        case 401, 403: throw IllustrationError.failed("Brave Search: недійсний ключ API")
        case 429: throw IllustrationError.failed("Brave Search: вичерпано ліміт запитів")
        default: throw IllustrationError.failed("Brave Search: HTTP \(status)")
        }
        let results = try JSONDecoder().decode(Response.self, from: body).web?.results ?? []
        var stories: [Illustration] = []
        for result in results {
            let text = HTMLText.plain(result.description ?? "")
            guard !text.isEmpty, let host = IllustrationSources.host(of: result.url) else { continue }
            stories.append(Illustration(title: HTMLText.plain(result.title), text: text, source: result.url, siteName: host,
                                        date: result.page_age.map { String($0.prefix(10)) }, isExcerpt: true))
        }
        return IllustrationPage(stories: stories, hasMore: results.count == Self.pageSize && page < Self.maxPages)
    }
}

/// Post HTML → plain text: paragraphs on new lines, entities decoded, scripts and styles removed.
public enum HTMLText {
    public static func plain(_ html: String) -> String {
        var text = html
        for tag in ["script", "style", "figure", "iframe"] {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<(br|/p|/h[1-6]|/li|/blockquote|/div)[^>]*>", with: "\n",
                                         options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        let lines = text.components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: "[ \\t\\u00A0]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n\n")
    }

    static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "mdash": "—", "ndash": "–", "hellip": "…",
    ]

    /// `&amp;`, `&#8217;`, `&#x2019;`; an unknown entity stays as is.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(10).firstIndex(of: ";"), let decoded = entity(String(after[..<semi])) {
                result += decoded
                rest = after[after.index(after: semi)...]
            } else {
                result += "&"
                rest = after
            }
        }
        return result + rest
    }

    private static func entity(_ name: String) -> String? {
        let code: UInt32?
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            code = UInt32(name.dropFirst(2), radix: 16)
        } else if name.hasPrefix("#") {
            code = UInt32(name.dropFirst())
        } else {
            return named[name]
        }
        guard let code, let scalar = Unicode.Scalar(code) else { return nil }
        return String(Character(scalar))
    }
}

/// Story search in batches of 7 (FR-33): "Get more" continues from where it stopped.
/// Order: queries from narrower to broader, in each the sources in turn, page after page.
public actor IllustrationSearch {
    public static let batchSize = 7

    private var queries: [String]
    private let keywords: [String]
    private let request: IllustrationRequest
    /// The model that writes queries and curates stories (FR-41); `nil` means sorting by keywords.
    private var curator: IllustrationCurator?
    private var planned = false
    /// Curated by the model, best first: "Get more" takes the next ones from here.
    private var curated: [(score: Int, story: Illustration)] = []
    /// Why model curation did not work (the caption under the stories); search then runs without the model.
    public private(set) var curatorProblem: String?
    /// How many times the model scores candidates per "Get more": the search cost is predictable;
    /// if fewer than 7 qualify, show fewer, and "Get more" stays.
    public static let judgementsPerBatch = 2
    private let providers: [IllustrationProvider]
    private let sources: IllustrationSources
    private let http: IllustrationHTTP
    private struct Cursor: Sendable { var query: Int, provider: Int, page: Int }
    /// `nil` means everything has been tried.
    private var cursor: Cursor?
    private var pending: [Illustration] = []
    private var seen = Set<String>()
    /// Sources that answered with an error: search continues without them (a site may rate-limit requests).
    private var failed = Set<Int>()
    private var lastError: IllustrationError?

    /// Sources: WordPress sites from the configuration, Wikipedia and, with a key, Brave over the whole allowlist.
    public static func providers(sources: IllustrationSources, braveKey: String?) -> [IllustrationProvider] {
        var providers: [IllustrationProvider] = sources.wordpress.map(WordPressAdapter.init(site:))
        providers.append(WikipediaAdapter())
        // Brave does not search Wikipedia: its articles must pass the `WikipediaAdapter` category filter.
        let braveSites = sources.allow.filter { $0 != WikipediaAdapter.host }
        // Brave limits a query to 400 characters and 50 words: the allowlist is split into groups of `sitesPerQuery` `site:`.
        if let braveKey, !braveKey.isEmpty {
            for start in stride(from: 0, to: braveSites.count, by: BraveAdapter.sitesPerQuery) {
                let group = Array(braveSites[start..<min(start + BraveAdapter.sitesPerQuery, braveSites.count)])
                providers.append(BraveAdapter(key: braveKey, sites: group))
            }
        }
        return providers
    }

    public init(request: IllustrationRequest, sources: IllustrationSources, providers: [IllustrationProvider],
                http: IllustrationHTTP, curator: IllustrationCurator? = nil) {
        let queries = IllustrationQuery.queries(from: request.kjvText)
        self.queries = queries
        self.request = request
        self.curator = curator
        self.keywords = IllustrationQuery.keywords(from: request.kjvText)
        self.providers = providers
        self.sources = sources
        self.http = http
        self.cursor = queries.isEmpty || providers.isEmpty ? nil : Cursor(query: 0, provider: 0, page: 1)
    }

    /// There is more to search: not all queries, sources and pages have been tried.
    public var hasMore: Bool { cursor != nil || !pending.isEmpty || !curated.isEmpty }

    /// The name of the model curating stories; `nil` means no model (or it failed).
    public var curatorName: String? { curator?.name }

    /// The next up to 7 stories, most relevant first; fewer means nothing more was found.
    /// One source's error does not stop the others; it throws only if nothing was found. Without network, immediately.
    public func next() async throws -> [Illustration] {
        lastError = nil
        // An explicit retry ("Retry" or "Get more") asks the sources that failed last time again.
        failed.removeAll()
        if curator != nil { return try await nextCurated() }
        // The model failed mid-search: first what it has already curated.
        if !curated.isEmpty {
            let batch = curated.prefix(Self.batchSize).map(\.story)
            curated.removeFirst(batch.count)
            return batch
        }
        while pending.count < Self.batchSize, try await fetchPage() {}
        if pending.isEmpty, let lastError { throw lastError }
        let batch = Array(pending.prefix(Self.batchSize))
        pending.removeFirst(batch.count)
        let ranked = batch.enumerated().map { (score: score($0.element), offset: $0.offset, story: $0.element) }
        return ranked.sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }.map(\.story)
    }

    /// A batch curated by the model: candidates in a pool (21 for Claude), at most two scorings at a time, threshold 6, best first.
    /// The model did not answer or answered with non-JSON: continue without it, with the candidates already found.
    private func nextCurated() async throws -> [Illustration] {
        await plan()
        var judgements = 0
        while curated.count < Self.batchSize, judgements < Self.judgementsPerBatch, let pool = curator?.candidatePool {
            while pending.count < pool, try await fetchPage() {}
            guard !pending.isEmpty else { break }
            judgements += 1
            let candidates = Array(pending.prefix(pool))
            guard let verdicts = await judge(candidates) else { return try await next() }
            pending.removeFirst(candidates.count)
            for (index, story) in candidates.enumerated() {
                guard let verdict = verdicts[index], verdict.score >= CuratorPrompts.threshold else { continue }
                var chosen = story
                chosen.reason = verdict.reason.isEmpty ? nil : verdict.reason
                curated.append((verdict.score, chosen))
            }
            // Stable: by score, ties in search order.
            curated = curated.enumerated().sorted { $0.element.score != $1.element.score
                ? $0.element.score > $1.element.score : $0.offset < $1.offset }.map(\.element)
        }
        if curator == nil, curated.isEmpty { return try await next() }
        if curated.isEmpty, let lastError { throw lastError }
        let batch = curated.prefix(Self.batchSize).map(\.story)
        curated.removeFirst(batch.count)
        return batch
    }

    /// Model queries from the verse meaning first, then by keywords (once per search).
    private func plan() async {
        guard !planned, let curator else { return }
        planned = true
        do {
            let answer = try await curator.complete(system: CuratorPrompts.system, prompt: CuratorPrompts.queriesPrompt(for: request))
            let extra = CuratorPrompts.queries(from: answer).filter { query in !queries.contains { $0.lowercased() == query.lowercased() } }
            queries = extra + queries
            if cursor == nil, !queries.isEmpty, !providers.isEmpty { cursor = Cursor(query: 0, provider: 0, page: 1) }
        } catch {
            give(up: error)
        }
    }

    /// Candidate scores; `nil` means the model is unavailable, continue without it.
    private func judge(_ candidates: [Illustration]) async -> [Int: CuratorVerdict]? {
        guard let curator else { return nil }
        do {
            let answer = try await curator.complete(system: CuratorPrompts.system,
                                                    prompt: CuratorPrompts.rankPrompt(for: request, candidates: candidates,
                                                                                      excerptLength: curator.excerptLength))
            guard let verdicts = CuratorPrompts.verdicts(from: answer, count: candidates.count) else {
                give(up: IllustrationError.failed("незрозуміла відповідь моделі"))
                return nil
            }
            return verdicts
        } catch {
            give(up: error)
            return nil
        }
    }

    private func give(up error: Error) {
        guard let curator else { return }
        let message: String
        switch error {
        case IllustrationError.offline: message = "немає мережі"
        case IllustrationError.failed(let text): message = text
        default: message = "\(error)"
        }
        curatorProblem = "\(curator.name): \(message)"
        self.curator = nil
    }

    /// Keywords in the title count double.
    private func score(_ story: Illustration) -> Int {
        let title = story.title.lowercased(), text = story.text.lowercased()
        var score = 0
        for word in keywords {
            if title.contains(word) { score += 2 }
            if text.contains(word) { score += 1 }
        }
        return score
    }

    private static func titleKey(_ title: String) -> String {
        "title:" + title.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// One more page of one source into `pending`; `false` means the cursor is exhausted.
    private func fetchPage() async throws -> Bool {
        guard let position = cursor else { return false }
        let page: IllustrationPage
        do {
            page = failed.contains(position.provider)
                ? IllustrationPage(stories: [], hasMore: false)
                : try await providers[position.provider].page(queries[position.query], page: position.page, http: http)
        } catch IllustrationError.offline {
            throw IllustrationError.offline
        } catch {
            failed.insert(position.provider)
            lastError = (error as? IllustrationError) ?? .failed("\(error)")
            page = IllustrationPage(stories: [], hasMore: false)
        }
        for story in page.stories where sources.isAllowed(story.source) {
            // A duplicate is the same address or the same title from another source.
            guard !seen.contains(story.source), !seen.contains(Self.titleKey(story.title)) else { continue }
            seen.insert(story.source)
            seen.insert(Self.titleKey(story.title))
            pending.append(story)
        }
        if page.hasMore {
            cursor = Cursor(query: position.query, provider: position.provider, page: position.page + 1)
        } else if position.provider + 1 < providers.count {
            cursor = Cursor(query: position.query, provider: position.provider + 1, page: 1)
        } else if position.query + 1 < queries.count {
            cursor = Cursor(query: position.query + 1, provider: 0, page: 1)
        } else {
            cursor = nil
        }
        return true
    }
}
