import Foundation

/// Єдиний файл з мережею в додатку (NFR-2): GET до сайтів ілюстрацій після кліку користувача.
/// Хости приходять з `IllustrationSources` (allowlist) і API Вікіпедії та Brave; інших запитів немає.
public struct IllustrationNetwork: IllustrationHTTP {
    public static let userAgent = "BibleReader/0.1 (macOS; github.com/taran-7/bible-reader)"
    private let session: URLSession

    /// `configuration` — для тестів (підставний `URLProtocol`), у додатку — ефемерна сесія без кешу й cookies.
    public init(timeout: TimeInterval = 15, configuration: URLSessionConfiguration = .ephemeral) {
        // Копія: переданий об'єкт (спільний у тестах) не змінюється.
        let configuration = configuration.copy() as! URLSessionConfiguration
        configuration.timeoutIntervalForRequest = timeout
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = Self.userAgent
        configuration.httpAdditionalHeaders = headers
        session = URLSession(configuration: configuration)
    }

    public func get(host: String, path: String, query: [(String, String)], headers: [String: String]) async throws -> (status: Int, body: Data) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw IllustrationError.failed("некоректна адреса \(host)\(path)") }
        var request = URLRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        do {
            let (data, response) = try await session.data(for: request)
            // Запит https — відповідь HTTP; інакше код 0, і адаптер вважає відповідь невдалою.
            return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw IllustrationError.offline
        } catch {
            throw IllustrationError.failed(error.localizedDescription)
        }
    }

    /// Посилання картки для відкриття в браузері: ще раз через allowlist, а не лише на слово адаптера.
    public static func link(for story: Illustration, sources: IllustrationSources) -> URL? {
        sources.isAllowed(story.source) ? URL(string: story.source) : nil
    }

    /// Сторінка, де користувач бере безкоштовний ключ Brave Search API (посилання в Settings).
    public static let braveKeyPage = URL(string: "https://brave.com/search/api/")!

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut,
    ]
}

extension IllustrationSources {
    /// Схема і хост адреси (нижній регістр, без `www.`); `nil` — не абсолютна адреса.
    /// Адреса з userinfo (`https://trusted.org:x@evil.example/`) відкидається: браузер відкрив би інший хост,
    /// ніж той, що пройшов allowlist (security review 2026-09-28). Тут, бо `URLComponents` — лише в мережевому файлі (NFR-2).
    static func parse(_ address: String) -> (scheme: String, host: String)? {
        guard !address.contains("\\"), let components = URLComponents(string: address),
              components.user == nil, components.password == nil,
              let scheme = components.scheme, let host = components.host, !host.isEmpty else { return nil }
        return (scheme.lowercased(), bare(host))
    }

    static func host(of address: String) -> String? { parse(address)?.host }
}
