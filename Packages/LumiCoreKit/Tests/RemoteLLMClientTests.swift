import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import Testing
@testable import LumiCoreKit

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

private struct RemoteMockProvider: SuperLLMProvider {
    static let id = "remote-mock"
    static let displayName = "Remote Mock"
    static let description = "Test"
    static let apiKeyStorageKey = ""
    static let defaultModel = "mock-model"

    var baseURL: String { "https://api.test/v1/messages" }

    init() {}

    func buildRequest(url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        ["model": model, "messages": messages.count]
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        ("pong", nil)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? { nil }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        [:]
    }

    func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .apiKeyOnly
    }
}

@Suite("RemoteLLMClient", .serialized)
struct RemoteLLMClientTests {
    private func makeAPIService() -> LLMAPIService {
        let client = HTTPClient { config in
            config.protocolClasses = [MockURLProtocol.self]
        }
        return LLMAPIService(client: client)
    }

    private func okResponse(url: URL = URL(string: "https://api.test/v1/messages")!) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    @Test("sendChat returns parsed assistant message")
    func sendChatSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (self.okResponse(), Data("{}".utf8))
        }
        defer { MockURLProtocol.reset() }

        let conversationId = UUID()
        let config = LLMConfig(model: RemoteMockProvider.defaultModel, providerId: RemoteMockProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: conversationId, content: "Hi")]

        let message = try await RemoteLLMClient.sendChat(
            provider: RemoteMockProvider(),
            messages: messages,
            config: config,
            tools: nil,
            apiService: makeAPIService()
        )

        #expect(message.content == "pong")
        #expect(message.conversationId == conversationId)
        #expect(message.providerId == RemoteMockProvider.id)
    }

    @Test("sendChat maps HTTP errors with status code")
    func sendChatHttpError() async {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data("forbidden".utf8))
        }
        defer { MockURLProtocol.reset() }

        let config = LLMConfig(model: RemoteMockProvider.defaultModel, providerId: RemoteMockProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: UUID(), content: "Hi")]

        await #expect(throws: LLMServiceError.self) {
            try await RemoteLLMClient.sendChat(
                provider: RemoteMockProvider(),
                messages: messages,
                config: config,
                tools: nil,
                apiService: makeAPIService()
            )
        }
    }
}
