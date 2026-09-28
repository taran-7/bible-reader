import Foundation

// Ілюстрації (FR-33…FR-35, PRD 6.17): реальні історії до виділених віршів з протестантських сайтів.
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
    public var id: String { source }

    public init(title: String, text: String, source: String, siteName: String, date: String? = nil) {
        self.title = title
        self.text = text
        self.source = source
        self.siteName = siteName
        self.date = date
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
    /// Сайти з пошуком WordPress REST. Решта allowlist закрита від ботів (Cloudflare) і не опитується.
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
    /// GET за захищеною адресою `<host><path>?<query>`; повертає код відповіді і тіло.
    func get(host: String, path: String, query: [(String, String)]) async throws -> (status: Int, body: Data)
}

public enum IllustrationError: Error, Equatable, Sendable {
    /// Немає мережі: повідомлення «Немає підключення до мережі».
    case offline
    case failed(String)
}

/// Пошук WordPress REST (`/wp-json/wp/v2/search`) і текст допису (`/wp-json/wp/v2/posts/<id>`).
public struct WordPressAdapter: Sendable {
    public let site: IllustrationSources.Site
    public static let pageSize = 10

    public init(site: IllustrationSources.Site) {
        self.site = site
    }

    /// Знайдений допис до завантаження тексту.
    public struct Hit: Hashable, Sendable {
        public let title: String
        public let url: String
        public let contentPath: String
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
        let title: Rendered
        let content: Rendered
        let link: String
        let date: String?
    }

    /// Сторінка результатів; порожній масив — сторінок більше немає (WordPress на зайву сторінку дає 400).
    public func search(_ text: String, page: Int, http: IllustrationHTTP) async throws -> [Hit] {
        let (status, body) = try await http.get(host: site.host, path: "/wp-json/wp/v2/search", query: [
            ("search", text), ("type", "post"), ("subtype", "post"),
            ("per_page", "\(Self.pageSize)"), ("page", "\(page)"),
        ])
        if status == 400 { return [] }
        guard status == 200 else { throw IllustrationError.failed("\(site.host): HTTP \(status)") }
        let items = try JSONDecoder().decode([SearchItem].self, from: body)
        return items.compactMap { item in
            guard item.subtype == nil || item.subtype == "post", let href = item._links?.links.first?.href,
                  let path = Self.path(of: href, host: site.host) else { return nil }
            return Hit(title: HTMLText.plain(item.title), url: item.url, contentPath: path)
        }
    }

    /// Текст допису; `nil` — допис порожній або не читається.
    public func illustration(_ hit: Hit, http: IllustrationHTTP) async throws -> Illustration? {
        let (status, body) = try await http.get(host: site.host, path: hit.contentPath,
                                                query: [("_fields", "title,content,link,date")])
        guard status == 200, let post = try? JSONDecoder().decode(Post.self, from: body) else { return nil }
        let text = HTMLText.plain(post.content.rendered)
        guard !text.isEmpty else { return nil }
        return Illustration(title: HTMLText.plain(post.title.rendered), text: text, source: post.link,
                            siteName: site.name, date: post.date.map { String($0.prefix(10)) })
    }

    /// Шлях `/wp-json/...` з адреси API того самого сайту; чужий хост — `nil`.
    static func path(of href: String, host: String) -> String? {
        guard let hrefHost = IllustrationSources.host(of: href),
              hrefHost == IllustrationSources.bare(host),
              let start = href.range(of: "/wp-json/") else { return nil }
        return String(href[start.lowerBound...])
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

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(10).firstIndex(of: ";") {
                let name = after[..<semi]
                var decoded: String?
                if name.hasPrefix("#x") || name.hasPrefix("#X") {
                    decoded = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else if name.hasPrefix("#") {
                    decoded = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else {
                    decoded = named[String(name)]
                }
                if let decoded {
                    result += decoded
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }
}

/// Пошук історій партіями по 7 (FR-33): «Отримати ще» продовжує з того місця, де зупинились.
/// Порядок: запити від вужчого до ширшого, у кожному — сайти по черзі, сторінка за сторінкою.
public actor IllustrationSearch {
    public static let batchSize = 7

    private let queries: [String]
    private let keywords: [String]
    private let adapters: [WordPressAdapter]
    private let sources: IllustrationSources
    private let http: IllustrationHTTP
    /// Курсор: запит, сайт, сторінка; `nil` — усе перебрано.
    private struct Cursor: Sendable { var query: Int, adapter: Int, page: Int }
    private var cursor: Cursor?
    private var pending: [(WordPressAdapter, WordPressAdapter.Hit)] = []
    private var seen = Set<String>()

    public init(request: IllustrationRequest, sources: IllustrationSources, http: IllustrationHTTP) {
        let queries = IllustrationQuery.queries(from: request.kjvText)
        let adapters = sources.wordpress.map(WordPressAdapter.init(site:))
        self.queries = queries
        self.keywords = IllustrationQuery.keywords(from: request.kjvText)
        self.adapters = adapters
        self.sources = sources
        self.http = http
        self.cursor = queries.isEmpty || adapters.isEmpty ? nil : Cursor(query: 0, adapter: 0, page: 1)
    }

    /// Є ще що шукати: не всі запити, сайти й сторінки перебрано.
    public var hasMore: Bool { cursor != nil || !pending.isEmpty }

    /// Наступні до 7 історій; менше — більше не знайшлося.
    public func next() async throws -> [Illustration] {
        var batch: [Illustration] = []
        while batch.count < Self.batchSize {
            if pending.isEmpty {
                guard try await fetchHits() else { break }
                continue
            }
            let take = pending.prefix(Self.batchSize - batch.count)
            pending.removeFirst(take.count)
            let stories = try await withThrowingTaskGroup(of: (Int, Illustration?).self) { group in
                for (index, (adapter, hit)) in take.enumerated() {
                    group.addTask { [http] in (index, try await adapter.illustration(hit, http: http)) }
                }
                var found: [(Int, Illustration)] = []
                for try await (index, story) in group { if let story { found.append((index, story)) } }
                return found.sorted { $0.0 < $1.0 }.map(\.1)
            }
            for story in stories where sources.isAllowed(story.source) && seen.insert(Self.titleKey(story.title)).inserted {
                batch.append(story)
            }
        }
        // Найрелевантніші першими: більше ключових слів у заголовку й тексті.
        return batch.enumerated().sorted { a, b in
            let (sa, sb) = (score(a.element), score(b.element))
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }

    private func score(_ story: Illustration) -> Int {
        let title = story.title.lowercased(), text = story.text.lowercased()
        return keywords.reduce(0) { $0 + (title.contains($1) ? 2 : 0) + (text.contains($1) ? 1 : 0) }
    }

    private static func titleKey(_ title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Ще одна сторінка пошуку в `pending`; `false` — курсор вичерпано.
    private func fetchHits() async throws -> Bool {
        guard let position = cursor else { return false }
        let adapter = adapters[position.adapter]
        let hits = try await adapter.search(queries[position.query], page: position.page, http: http)
        let fresh = hits.filter { sources.isAllowed($0.url) && seen.insert($0.url).inserted }
        pending.append(contentsOf: fresh.map { (adapter, $0) })
        // Повна сторінка — у цього сайту можуть бути ще; інакше наступний сайт, потім наступний запит.
        if hits.count == WordPressAdapter.pageSize {
            cursor = Cursor(query: position.query, adapter: position.adapter, page: position.page + 1)
        } else if position.adapter + 1 < adapters.count {
            cursor = Cursor(query: position.query, adapter: position.adapter + 1, page: 1)
        } else if position.query + 1 < queries.count {
            cursor = Cursor(query: position.query + 1, adapter: 0, page: 1)
        } else {
            cursor = nil
        }
        return true
    }
}
