import Foundation
import Testing
@testable import BibleCore

/// A stub `URLProtocol`: answers without network and remembers the request.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var result: Result<(Int, Data), URLError> = .success((200, Data()))
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lastRequest = request
        switch Self.result {
        case .success(let (status, data)):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

/// The illustrations network file (NFR-2) without a real network; tests are serialized because of the stub's shared state.
@Suite(.serialized) struct IllustrationNetworkTests {
    func network() -> IllustrationNetwork {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return IllustrationNetwork(configuration: configuration)
    }

    // @trace FR-35
    @Test func testBuildsHttpsRequestWithQueryAndHeaders() async throws {
        StubURLProtocol.result = .success((200, Data("ok".utf8)))
        let (status, body) = try await network().get(host: "www.imb.org", path: "/wp-json/wp/v2/search",
                                                     query: [("search", "love enemies"), ("page", "2")], headers: ["X-Test": "1"])
        #expect(status == 200 && body == Data("ok".utf8))
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://www.imb.org/wp-json/wp/v2/search?search=love%20enemies&page=2")
        #expect(request.value(forHTTPHeaderField: "X-Test") == "1")
    }

    // @trace FR-41
    @Test func testPostSendsJSONBody() async throws {
        StubURLProtocol.result = .success((200, Data("{}".utf8)))
        let (status, _) = try await network().post(host: "api.anthropic.com", path: "/v1/messages",
                                                   headers: ["x-api-key": "k"], body: Data("{\"a\":1}".utf8))
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(status == 200 && request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "k")
        #expect(IllustrationNetwork.claudeKeyPage.host == "console.anthropic.com")
    }

    // @trace FR-33
    @Test func testNoConnectionIsOffline() async {
        StubURLProtocol.result = .failure(URLError(.notConnectedToInternet))
        await #expect(throws: IllustrationError.offline) {
            try await network().get(host: "www.imb.org", path: "/", query: [], headers: [:])
        }
    }

    // @trace FR-33
    @Test func testOtherErrorsAreFailures() async {
        StubURLProtocol.result = .failure(URLError(.badServerResponse))
        await #expect(throws: (any Error).self) {
            try await network().get(host: "www.imb.org", path: "/", query: [], headers: [:])
        }
        do {
            _ = try await network().get(host: "www.imb.org", path: "/", query: [], headers: [:])
        } catch {
            #expect(error as? IllustrationError != .offline)
        }
        // A path without a leading "/": URLComponents does not build the address.
        await #expect(throws: (any Error).self) {
            try await network().get(host: "www.imb.org", path: "no-slash", query: [], headers: [:])
        }
    }

    // @trace FR-33
    @Test func testLinkForStory() {
        let story = Illustration(title: "T", text: "B", source: "https://www.imb.org/x", siteName: "IMB")
        let sources = IllustrationSources(allow: ["imb.org"], block: [], wordpress: [])
        #expect(IllustrationNetwork.link(for: story, sources: sources)?.host == "www.imb.org")
        let foreign = Illustration(title: "T", text: "B", source: "https://evil.example/x", siteName: "IMB")
        #expect(IllustrationNetwork.link(for: foreign, sources: sources) == nil)
        #expect(IllustrationNetwork.braveKeyPage.host == "brave.com")
    }
}
