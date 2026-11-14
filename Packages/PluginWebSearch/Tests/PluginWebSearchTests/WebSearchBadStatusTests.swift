import Foundation
import KitAgentTool
import ProviderNetwork
import Testing
@testable import PluginWebSearch

/// 回归 #332：web_search 必须检查 HTTP 状态码。
///
/// 旧实现拿到响应后直接解析 body，429/500 的错误页不含 `result__a`，
/// 会被解析成空数组并渲染成「No results found」的成功结果，把服务限流/故障
/// 伪装成一次合法的空搜索。这里用网络替身固定状态码，驱动真实的
/// `fetchDuckDuckGoResults` 链路验证：非 2xx 必须按真实状态码抛出，
/// 而 2xx 的正常解析与合法空结果不受影响。
@Suite("WebSearch bad status")
@MainActor
struct WebSearchBadStatusTests {
    /// 只按预设状态码与 body 回应的网络替身；工具只会走 `get`。
    private final class StubSearchNetwork: NetworkProviding, @unchecked Sendable {
        let statusCode: Int
        let body: Data

        init(statusCode: Int, body: Data) {
            self.statusCode = statusCode
            self.body = body
        }

        private func respond(url: URL) -> HTTPResponse {
            HTTPResponse(statusCode: statusCode, headers: [:], body: body, url: url)
        }

        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            respond(url: request.url)
        }

        func get(url: URL, headers: [String: String], timeout: TimeInterval) async throws -> HTTPResponse {
            respond(url: url)
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {}

        func post(url: URL, body: Data, contentType: String, headers: [String: String], timeout: TimeInterval) async throws -> HTTPResponse {
            respond(url: url)
        }

        func json<T: Sendable, R: Sendable>(
            url: URL, method: HTTPMethod, body: T, headers: [String: String], timeout: TimeInterval
        ) async throws -> R where T: Encodable, R: Decodable {
            throw WebSearchError.invalidResponse
        }

        func download(from url: URL, to destination: URL, headers: [String: String], timeout: TimeInterval) async throws -> URL {
            throw WebSearchError.invalidResponse
        }
    }

    /// 不含任何 `result__a` 的错误页：旧实现会把它解析成空数组。
    private let errorPage = Data("""
    <html><head><title>429 Too Many Requests</title></head>
    <body><h1>Rate limited</h1><p>Please slow down.</p></body></html>
    """.utf8)

    private let resultPage = Data("""
    <div class="result">
      <a href="/l/?uddg=https%3A%2F%2Fexample.com%2Fa" class="result__a">Example Result</a>
      <a class="result__snippet">A useful summary.</a>
    </div>
    """.utf8)

    @Test("a 429 error page must throw badStatus, not masquerade as no results")
    func rateLimitThrowsBadStatus() async throws {
        let network = StubSearchNetwork(statusCode: 429, body: errorPage)
        let thrown = try #require(await #expect(throws: WebSearchError.self) {
            _ = try await WebSearchTool.fetchDuckDuckGoResults(query: "anything", network: network)
        })
        guard case .badStatus(let code) = thrown else {
            Issue.record("expected badStatus, got \(thrown)")
            return
        }
        #expect(code == 429)
    }

    @Test("a 500 error page must throw badStatus with the real code")
    func serverErrorThrowsBadStatus() async throws {
        let network = StubSearchNetwork(statusCode: 500, body: errorPage)
        let thrown = try #require(await #expect(throws: WebSearchError.self) {
            _ = try await WebSearchTool.fetchDuckDuckGoResults(query: "anything", network: network)
        })
        guard case .badStatus(let code) = thrown else {
            Issue.record("expected badStatus, got \(thrown)")
            return
        }
        #expect(code == 500)
    }

    @Test("a 200 response still parses real results")
    func successStillParsesResults() async throws {
        let network = StubSearchNetwork(statusCode: 200, body: resultPage)
        let results = try await WebSearchTool.fetchDuckDuckGoResults(query: "example", network: network)
        let first = try #require(results.first)
        #expect(first.title == "Example Result")
        #expect(first.url == "https://example.com/a")
    }

    @Test("a 200 response with no results stays a legitimate empty result")
    func successWithNoResultsStaysEmpty() async throws {
        let network = StubSearchNetwork(statusCode: 200, body: errorPage)
        let results = try await WebSearchTool.fetchDuckDuckGoResults(query: "unknown term", network: network)
        #expect(results.isEmpty)
    }
}