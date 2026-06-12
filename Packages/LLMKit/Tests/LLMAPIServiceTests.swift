import Testing
import Foundation
import HttpKit
@testable import LLMKit

// MARK: - Mock URLProtocol for LLMAPIService Tests

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    static func setHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        _handler = handler
    }

    static func reset() {
        _handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self._handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("LLMAPIService Tests", .serialized)
struct LLMAPIServiceTests {

    private func makeClient(protocols: [AnyClass]) -> HTTPClient {
        HTTPClient { config in
            config.protocolClasses = protocols
        }
    }

    private func okResponse(url: URL = URL(string: "https://api.test")!) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    private func errorResponse(code: Int, url: URL = URL(string: "https://api.test")!) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    // MARK: - sendChatRequest

    @Test("sendChatRequest 成功返回 Data")
    func sendChatRequestSuccess() async throws {
        let expectedData = Data("{\"content\":\"hello\"}".utf8)
        MockURLProtocol.setHandler { _ in (self.okResponse(), expectedData) }
        defer { MockURLProtocol.reset() }

        let service = LLMAPIService(client: makeClient(protocols: [MockURLProtocol.self]))
        var request = URLRequest(url: URL(string: "https://api.test/v1/chat")!)
        request.httpMethod = "POST"

        let data = try await service.sendChatRequest(
            request: request,
            body: ["model": "gpt-4o", "messages": []]
        )
        #expect(data == expectedData)
    }

    @Test("sendChatRequest 传播 HTTP 错误")
    func sendChatRequestHttpError() async {
        MockURLProtocol.setHandler { _ in
            (self.errorResponse(code: 500), Data("Internal Server Error".utf8))
        }
        defer { MockURLProtocol.reset() }

        let service = LLMAPIService(client: makeClient(protocols: [MockURLProtocol.self]))
        let request = URLRequest(url: URL(string: "https://api.test/v1/chat")!)

        do {
            _ = try await service.sendChatRequest(request: request, body: [:])
            Issue.record("应该抛出错误")
        } catch {
            // 预期会抛出 HTTPClientError
        }
    }

    @Test("sendChatRequest 传播网络错误")
    func sendChatRequestNetworkError() async {
        MockURLProtocol.setHandler { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }
        defer { MockURLProtocol.reset() }

        let service = LLMAPIService(client: makeClient(protocols: [MockURLProtocol.self]))
        let request = URLRequest(url: URL(string: "https://api.test/v1/chat")!)

        do {
            _ = try await service.sendChatRequest(request: request, body: [:])
            Issue.record("应该抛出错误")
        } catch {
            // 预期会抛出 HTTPClientError
        }
    }

    // MARK: - 初始化

    @Test("默认初始化不崩溃")
    func defaultInit() {
        _ = LLMAPIService()
        // 无崩溃即通过
    }

    @Test("注入自定义 HTTPClient")
    func customClientInit() {
        let client = HTTPClient()
        _ = LLMAPIService(client: client)
    }
}
