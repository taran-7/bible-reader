import Foundation

// Ілюстрації (FR-33…FR-35, PRD 6.17): реальні історії до виділених віршів — протестантські сайти, Вікіпедія, Brave.
// Живий пошук під час кліку, без локального індексу й без збереження: мережа — лише в `IllustrationNetwork`,
// тут — побудова запитів, розбір відповідей, allowlist, дедуплікація і партії по 7.

/// Виділені вірші для вікна ілюстрацій: посилання мовою екрана і текст у KJV (пошук англійською).
public struct IllustrationRequest: Codable, Hashable, Sendable {
    public let reference: String
    public let kjvText: [String]

    public init(reference: String, kjvText: [String]) {
        self.reference = reference
        self.kjvText = kjvText
    }
}

/// Історія: заголовок, текст сторінки, джерело. Нічого не зберігається — лише «Скопіювати».
public struct Illustration: Identifiable, Hashable, Sendable {
    public let title: String
    public let text: String
    public let source: String
    public let siteName: String
    public let date: String?
    /// Показано лише початок або уривок: у картці посилання «Читати на сайті».
    public let isExcerpt: Bool
    public var id: String { source }

    public init(title: String, text: String, source: String, siteName: String, date: String? = nil, isExcerpt: Bool = false) {
        self.title = title
        self.text = text
        self.source = source
        self.siteName = siteName
        self.date = date
        self.isExcerpt = isExcerpt
    }

    /// Текст для буфера: історія разом із джерелом, щоб її можна було вставити в нотатку.
    public var copyText: String {
        "\(title)\n\n\(text)\n\nДжерело: \(siteName), \(source)"
    }
}

/// Список джерел (`Resources/illustration-sources.json`, [illustration-sources.md](docs/product-specs/illustration-sources.md)).
public struct IllustrationSources: Decodable, Sendable {
    public struct Site: Decodable, Hashable, Sendable {
        public let name: String
        public let host: String
    }

    public let allow: [String]
    public let block: [String]
    /// Сайти з пошуком WordPress REST (повний текст). Решту allowlist, закриту від ботів, шукає Brave за `site:`.
    public let wordpress: [Site]

    public static func load(from data: Data) throws -> IllustrationSources {
        try JSONDecoder().decode(IllustrationSources.self, from: data)
    }

    public static var bundled: IllustrationSources {
        get throws {
            try load(from: Data(contentsOf: Bundle.module.url(forResource: "illustration-sources", withExtension: "json")!))
        }
    }

    /// Хост адреси `scheme://host/...` у нижньому регістрі без `www.`; `nil` — не абсолютна адреса.
    static func host(of address: String) -> String? {
        guard let scheme = address.range(of: "://") else { return nil }
        let rest = address[scheme.upperBound...]
        let host = rest.prefix { $0 != "/" && $0 != "?" && $0 != "#" && $0 != ":" }
        guard !host.isEmpty else { return nil }
        return bare(String(host))
    }

    /// Хост без `www.` у нижньому регістрі.
    static func bare(_ host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }

    private static func matches(_ host: String, _ domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    /// FR-34: історія береться лише з домену allowlist; blocklist перевіряється першим і перемагає.
    public func isAllowed(_ address: String) -> Bool {
        // Лише захищені адреси (схема https).
        guard let host = Self.host(of: address), address.split(separator: ":").first?.lowercased() == "https" else { return false }
        if block.contains(where: { Self.matches(host, $0) }) { return false }
        return allow.contains { Self.matches(host, $0) }
    }
}

/// Англійські ключові слова з тексту KJV: без службових слів, найчастіші першими.
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
        // Стабільно: частіші першими, серед рівних — у порядку тексту.
        let ranked = order.enumerated().sorted { a, b in
            let (ca, cb) = (counts[a.element]!, counts[b.element]!)
            return ca != cb ? ca > cb : a.offset < b.offset
        }
        return ranked.prefix(limit).map(\.element)
    }

    /// Запити від вужчого до ширшого: WordPress шукає всі слова разом, тож далі — пари і окремі слова.
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

/// Мережа ілюстрацій за протоколом: тести підставляють фікстури, додаток — `IllustrationNetwork`.
public protocol IllustrationHTTP: Sendable {
    /// GET за захищеною адресою `<host><path>?<query>` з заголовками; повертає код відповіді і тіло.
    func get(host: String, path: String, query: [(String, String)], headers: [String: String]) async throws -> (status: Int, body: Data)
}

public enum IllustrationError: Error, Equatable, Sendable {
    /// Немає мережі: повідомлення «Немає підключення до мережі».
    case offline
    case failed(String)
}

/// Сторінка одного джерела: історії після фільтрів і чи є в джерела наступна сторінка.
public struct IllustrationPage: Sendable {
    public let stories: [Illustration]
    public let hasMore: Bool

    public init(stories: [Illustration], hasMore: Bool) {
        self.stories = stories
        self.hasMore = hasMore
    }
}

/// Джерело історій: сторінка результатів за запитом.
public protocol IllustrationProvider: Sendable {
    func page(_ query: String, page: Int, http: IllustrationHTTP) async throws -> IllustrationPage
}

/// Текст картки для статей під авторським правом: початок і посилання «Читати на сайті».
public enum IllustrationExcerpt {
    public static let limit = 1500

    /// Обрізає по межі абзацу або речення в другій половині ліміту; `truncated` — текст скорочено.
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

/// Пошук WordPress REST (`/wp-json/wp/v2/search`) і текст допису (`/wp-json/wp/v2/posts/<id>`).
public struct WordPressAdapter: IllustrationProvider {
    public let site: IllustrationSources.Site
    static let pageSize = 10

    public init(site: IllustrationSources.Site) {
        self.site = site
    }

    /// Знайдений допис до завантаження тексту.
    struct Hit: Hashable, Sendable {
        let title: String
        let url: String
        /// Номер допису з адреси API `/wp-json/wp/v2/posts/<id>` того самого сайту.
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

    /// Сторінка результатів; порожній масив — сторінок більше немає (WordPress на зайву сторінку дає 400).
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

    /// Тексти всіх дописів сторінки одним запитом (`include=`), у порядку пошуку: сайти обмежують частоту запитів
    /// (Christianity Today відповідав 403 на десяток окремих). Початок ≤ 1500 символів — авторське право.
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

    /// Номер допису з адреси `…/wp-json/wp/v2/posts/<id>` того самого сайту; чужий хост чи інший тип — `nil`.
    static func postID(of href: String, host: String) -> Int? {
        guard let hrefHost = IllustrationSources.host(of: href), hrefHost == IllustrationSources.bare(host),
              let range = href.range(of: "/wp-json/wp/v2/posts/") else { return nil }
        return Int(href[range.upperBound...])
    }
}

/// Вікіпедія (CC BY-SA): лише біографії реальних людей (категорії «… births/deaths») і без католицьких
/// та православних тем (святі, папи, ченці тощо — рішення власника 2026-09-28); текст — вступ статті.
public struct WikipediaAdapter: IllustrationProvider {
    public static let host = "en.wikipedia.org"
    static let pageSize = 10
    /// Підказка до запиту: життєві історії християн, а не тлумачення віршів.
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

    /// Людина: є категорія «… births» або «… deaths».
    static func isPerson(_ categories: [String]) -> Bool {
        categories.contains { $0.hasSuffix(" births") || $0.hasSuffix(" deaths") }
    }

    /// Католицька чи православна тема: у назві категорії є одне зі слів `excludedWords`.
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
        // Відфільтровані статті не означають кінця: наступна сторінка є, якщо ця була повна.
        return IllustrationPage(stories: stories, hasMore: pages.count == Self.pageSize)
    }
}

/// Brave Search API (ключ користувача): пошук `site:` по всьому allowlist, зокрема по сайтах,
/// закритих від ботів. Сторінки не відкриваємо — лише заголовок, уривок пошуковика і посилання.
public struct BraveAdapter: IllustrationProvider {
    public static let host = "api.search.brave.com"
    public let key: String
    public let sites: [String]
    static let pageSize = 20
    /// Brave віддає до 10 сторінок (offset 0…9).
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

/// HTML допису → простий текст: абзаци з нового рядка, сутності розкодовано, скрипти й стилі прибрано.
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

    /// `&amp;`, `&#8217;`, `&#x2019;`; невідома сутність лишається як є.
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

/// Пошук історій партіями по 7 (FR-33): «Отримати ще» продовжує з того місця, де зупинились.
/// Порядок: запити від вужчого до ширшого, у кожному — джерела по черзі, сторінка за сторінкою.
public actor IllustrationSearch {
    public static let batchSize = 7

    private let queries: [String]
    private let keywords: [String]
    private let providers: [IllustrationProvider]
    private let sources: IllustrationSources
    private let http: IllustrationHTTP
    private struct Cursor: Sendable { var query: Int, provider: Int, page: Int }
    /// `nil` — усе перебрано.
    private var cursor: Cursor?
    private var pending: [Illustration] = []
    private var seen = Set<String>()
    /// Джерела, що відповіли помилкою: пошук іде далі без них (сайт може обмежувати частоту запитів).
    private var failed = Set<Int>()
    private var lastError: IllustrationError?

    /// Джерела: сайти WordPress з конфігурації, Вікіпедія і, з ключем, Brave по всьому allowlist.
    public static func providers(sources: IllustrationSources, braveKey: String?) -> [IllustrationProvider] {
        var providers: [IllustrationProvider] = sources.wordpress.map(WordPressAdapter.init(site:))
        providers.append(WikipediaAdapter())
        // Вікіпедію Brave не шукає: її статті мають пройти фільтр категорій `WikipediaAdapter`.
        let braveSites = sources.allow.filter { $0 != WikipediaAdapter.host }
        if let braveKey, !braveKey.isEmpty { providers.append(BraveAdapter(key: braveKey, sites: braveSites)) }
        return providers
    }

    public init(request: IllustrationRequest, sources: IllustrationSources, providers: [IllustrationProvider],
                http: IllustrationHTTP) {
        let queries = IllustrationQuery.queries(from: request.kjvText)
        self.queries = queries
        self.keywords = IllustrationQuery.keywords(from: request.kjvText)
        self.providers = providers
        self.sources = sources
        self.http = http
        self.cursor = queries.isEmpty || providers.isEmpty ? nil : Cursor(query: 0, provider: 0, page: 1)
    }

    /// Є ще що шукати: не всі запити, джерела й сторінки перебрано.
    public var hasMore: Bool { cursor != nil || !pending.isEmpty }

    /// Наступні до 7 історій, найрелевантніші першими; менше — більше не знайшлося.
    /// Помилка одного джерела не зупиняє інші; кидається, лише якщо нічого не знайшлося. Без мережі — одразу.
    public func next() async throws -> [Illustration] {
        lastError = nil
        while pending.count < Self.batchSize, try await fetchPage() {}
        if pending.isEmpty, let lastError { throw lastError }
        let batch = Array(pending.prefix(Self.batchSize))
        pending.removeFirst(batch.count)
        let ranked = batch.enumerated().map { (score: score($0.element), offset: $0.offset, story: $0.element) }
        return ranked.sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }.map(\.story)
    }

    /// Ключові слова в заголовку важать удвічі.
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

    /// Ще одна сторінка одного джерела в `pending`; `false` — курсор вичерпано.
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
            // Дублікат — та сама адреса або той самий заголовок з іншого джерела.
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
