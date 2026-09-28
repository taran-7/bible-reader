import Foundation

/// Єдиний файл з мережею в додатку (NFR-2): GET до сайтів ілюстрацій після кліку користувача.
/// Хости приходять з `IllustrationSources` (allowlist) і API Вікіпедії та Brave; інших запитів немає.
public struct IllustrationNetwork: IllustrationHTTP {
    public static let userAgent = "BibleReader/0.1 (macOS; github.com/taran-7/bible-reader)"
    private let session: URLSession

    public init(timeout: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.httpAdditionalHeaders = ["User-Agent": Self.userAgent]
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
            return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw IllustrationError.offline
        } catch {
            throw IllustrationError.failed(error.localizedDescription)
        }
    }

    /// Посилання картки для відкриття в браузері (лише https з allowlist — інакше історії б не було).
    public static func link(for story: Illustration) -> URL? {
        URL(string: story.source)
    }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut,
    ]
}
