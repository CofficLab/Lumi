import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import Testing
@testable import LLMProviderZhipuPlugin

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

@Suite("ZhipuChatTransport", .serialized)
struct ZhipuChatTransportTests {
    /// 智谱实际返回的 Anthropic 兼容错误体（App 中可见 `[HTTP 403] Request not allowed`）。
    private static let requestNotAllowedBody = Data(
        #"{"type":"error","error":{"type":"permission_error","message":"Request not allowed"}}"#.utf8
    )

    private func makeMockClient() -> HTTPClient {
        HTTPClient { config in
            config.protocolClasses = [MockURLProtocol.self]
        }
    }

    private func installApiKeyForTests() {
        ZhipuProvider.setApiKey("zhipu-test-key")
    }

    private func restoreHttpClient(_ previous: HTTPClient) {
        ZhipuChatTransport.httpClient = previous
        MockURLProtocol.reset()
        ZhipuProvider.removeApiKey()
    }

    @Test("sendMessage validates config before HTTP")
    func sendMessageValidatesConfig() async {
        var config = LLMConfig(model: ZhipuProvider.defaultModel, providerId: ZhipuProvider.id)
        config.model = ""

        let provider = ZhipuProvider()
        let messages = [ChatMessage(role: .user, conversationId: UUID(), content: "Hi")]

        await #expect(throws: LLMServiceError.modelEmpty) {
            try await ZhipuChatTransport.sendMessage(
                provider: provider,
                messages: messages,
                config: config,
                tools: nil
            )
        }
    }

    @Test("streamChat reproduces HTTP 403 Request not allowed")
    func streamChatHttp403RequestNotAllowed() async {
        installApiKeyForTests()
        let previousClient = ZhipuChatTransport.httpClient
        defer { restoreHttpClient(previousClient) }

        ZhipuChatTransport.httpClient = makeMockClient()
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Self.requestNotAllowedBody)
        }

        let provider = ZhipuProvider()
        let conversationId = UUID()
        let config = LLMConfig(model: ZhipuProvider.defaultModel, providerId: ZhipuProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: conversationId, content: "Hi")]

        do {
            _ = try await ZhipuChatTransport.streamChat(
                provider: provider,
                messages: messages,
                config: config,
                tools: nil,
                maxThinkingLength: 1_000,
                onChunk: { _ in },
                onRequestStart: { _ in }
            )
            Issue.record("Expected HTTP 403 error")
        } catch let error as LLMServiceError {
            guard case let .requestFailed(message, statusCode) = error else {
                Issue.record("Expected requestFailed, got \(error)")
                return
            }
            #expect(statusCode == 403)
            #expect(message == "[HTTP 403] Request not allowed")

            let chatError = provider.buildErrorChatMessage(
                error: error,
                conversationId: conversationId,
                rawDetail: message
            )
            #expect(chatError?.renderKind == ZhipuRenderKind.http(403))
            #expect(chatError?.rawErrorDetail == "[HTTP 403] Request not allowed")
            #expect(Http403Renderer().canRender(message: chatError!))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendMessage reproduces HTTP 403 Request not allowed")
    func sendMessageHttp403RequestNotAllowed() async {
        installApiKeyForTests()
        let previousClient = ZhipuChatTransport.httpClient
        defer { restoreHttpClient(previousClient) }

        ZhipuChatTransport.httpClient = makeMockClient()
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Self.requestNotAllowedBody)
        }

        let provider = ZhipuProvider()
        let config = LLMConfig(model: ZhipuProvider.defaultModel, providerId: ZhipuProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: UUID(), content: "Hi")]

        do {
            _ = try await ZhipuChatTransport.sendMessage(
                provider: provider,
                messages: messages,
                config: config,
                tools: nil
            )
            Issue.record("Expected HTTP 403 error")
        } catch let error as LLMServiceError {
            guard case let .requestFailed(message, statusCode) = error else {
                Issue.record("Expected requestFailed, got \(error)")
                return
            }
            #expect(statusCode == 403)
            #expect(message.contains("403"))
            #expect(message.contains("Request not allowed"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
