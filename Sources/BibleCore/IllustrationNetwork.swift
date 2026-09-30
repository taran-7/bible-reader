import Foundation

/// The only file with network code in the app (NFR-2): GET to illustration sites after the user's click.
/// Hosts come from `IllustrationSources` (allowlist) and the Wikipedia and Brave APIs; there are no other requests.
public struct IllustrationNetwork: IllustrationHTTP {
    public static let userAgent = "BibleReader/0.1 (macOS; github.com/taran-7/bible-reader)"
    private let session: URLSession

    /// `configuration`: for tests (a stub `URLProtocol`); in the app, an ephemeral session without cache and cookies.
    public init(timeout: TimeInterval = 15, configuration: URLSessionConfiguration = .ephemeral) {
        // A copy: the passed object (shared in tests) is not changed.
        let configuration = configuration.copy() as! URLSessionConfiguration
        configuration.timeoutIntervalForRequest = timeout
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = Self.userAgent
        configuration.httpAdditionalHeaders = headers
        session = URLSession(configuration: configuration)
    }

    public func get(host: String, path: String, query: [(String, String)], headers: [String: String]) async throws -> (status: Int, body: Data) {
        try await send(host: host, path: path, query: query, headers: headers, body: nil)
    }

    /// POST JSON: only to the API of the model that curates stories (FR-41).
    public func post(host: String, path: String, headers: [String: String], body: Data) async throws -> (status: Int, body: Data) {
        try await send(host: host, path: path, query: [], headers: headers, body: body)
    }

    private func send(host: String, path: String, query: [(String, String)], headers: [String: String],
                      body: Data?) async throws -> (status: Int, body: Data) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.isEmpty ? nil : query.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw IllustrationError.failed("некоректна адреса \(host)\(path)") }
        var request = URLRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
        }
        do {
            let (data, response) = try await session.data(for: request)
            // An https request gets an HTTP response; otherwise code 0, and the adapter treats the response as failed.
            guard let http = response as? HTTPURLResponse else { return (0, data) }
            return (http.statusCode, data)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw IllustrationError.offline
        } catch {
            throw IllustrationError.failed(error.localizedDescription)
        }
    }

    /// A card link to open in the browser: checked against the allowlist again, not just on the adapter's word.
    public static func link(for story: Illustration, sources: IllustrationSources) -> URL? {
        sources.isAllowed(story.source) ? URL(string: story.source) : nil
    }

    /// The page where the user gets a free Brave Search API key (a link in Settings).
    public static let braveKeyPage = URL(string: "https://brave.com/search/api/")!

    /// The Claude API keys page (a link in Settings, FR-41).
    public static let claudeKeyPage = URL(string: "https://console.anthropic.com/settings/keys")!

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut,
    ]
}

extension IllustrationSources {
    /// The scheme and host of an address (lowercase, without `www.`); `nil` means not an absolute address.
    /// An address with userinfo (`https://trusted.org:x@evil.example/`) is rejected: the browser would open a different host
    /// than the one that passed the allowlist (security review 2026-09-28). It lives here because `URLComponents` is only in the network file (NFR-2).
    static func parse(_ address: String) -> (scheme: String, host: String)? {
        guard !address.contains("\\"), let components = URLComponents(string: address),
              components.user == nil, components.password == nil,
              let scheme = components.scheme, let host = components.host, !host.isEmpty else { return nil }
        return (scheme.lowercased(), bare(host))
    }

    static func host(of address: String) -> String? { parse(address)?.host }
}
