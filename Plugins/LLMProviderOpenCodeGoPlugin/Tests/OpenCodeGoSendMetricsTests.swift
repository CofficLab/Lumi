import Foundation
import Testing
import HttpKit
import KernelLumi
import LLMKit
@testable import LLMProviderOpenCodeGoPlugin

// MARK: - Mock URLProtocol

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

// MARK: - send 性能字段

@Suite("OpenCodeGoProvider send 性能字段", .serialized)
struct OpenCodeGoSendMetricsTests {

    private func makeClient() -> HTTPClient {
        HTTPClient { config in
            config.protocolClasses = [MockURLProtocol.self]
        }
    }

    private func makeRequest(model: String = "deepseek-v4-flash") -> LumiLLMRequest {
        let conversationID = UUID()
        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "hi"
        )
        return LumiLLMRequest(messages: [userMessage], model: model)
    }

    /// 非流式响应：latencyMs / timeToFirstTokenMs 必须填充（二者相等），
    /// streamingDurationMs 保持 nil。ConversationSpeed 依赖这些字段计算 TPS。
    @Test("send 返回消息填充 latencyMs 与 timeToFirstTokenMs")
    func sendFillsSpeedMetrics() async throws {
        let json = """
        {
          "choices": [{"message": {"role": "assistant", "content": "hello world"}}],
          "usage": {"prompt_tokens": 12, "completion_tokens": 120}
        }
        """
        MockURLProtocol.setHandler { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://opencode.ai/zen/go/v1/chat/completions")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }
        defer { MockURLProtocol.reset() }

        let provider = OpenCodeGoProvider(apiService: LLMAPIService(client: makeClient()))
        provider.setApiKey("test-key")
        defer { provider.removeApiKey() }

        let message = try await provider.send(makeRequest())

        #expect(message.outputTokenCount == 120)
        #expect(message.latencyMs != nil)
        #expect(message.latencyMs! > 0)
        #expect(message.timeToFirstTokenMs == message.latencyMs)
        #expect(message.streamingDurationMs == nil)
    }

    /// Anthropic 协议（minimax-m3）同样需要填充时间字段。
    @Test("Anthropic 协议路径也填充时间字段")
    func anthropicPathFillsSpeedMetrics() async throws {
        let json = """
        {
          "content": [{"type": "text", "text": "hi there"}],
          "usage": {"input_tokens": 8, "output_tokens": 60}
        }
        """
        MockURLProtocol.setHandler { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://opencode.ai/zen/go/v1/messages")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }
        defer { MockURLProtocol.reset() }

        let provider = OpenCodeGoProvider(apiService: LLMAPIService(client: makeClient()))
        provider.setApiKey("test-key")
        defer { provider.removeApiKey() }

        let message = try await provider.send(makeRequest(model: "minimax-m3"))

        #expect(message.outputTokenCount == 60)
        #expect(message.latencyMs != nil)
        #expect(message.latencyMs! > 0)
        #expect(message.timeToFirstTokenMs == message.latencyMs)
        #expect(message.streamingDurationMs == nil)
    }
}
