import Foundation
import KitLLM
import os
import Testing
@testable import PluginLLMProviderOpenCode

/// OpenCode Go Responses 模型的流式路径（issue #413）。
///
/// ## 为什么要有这条测试
///
/// `grok-4.5` / `gpt-5.6-luna` 声明 `supportsStreaming = true`，但
/// streamComplete 此前直接调用一次性 sendResponses：请求不带
/// `stream: true`，onChunk 从未被调用，UI 干等到完整响应才更新。
@MainActor
struct GoProviderResponsesStreamingTests {

    private static let storageKey = "DevAssistant_ApiKey_OpenCodeGo"

    private static func withIsolatedAPIKey(_ value: String) {
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey.test.\(UUID().uuidString)"
        VendorAPIKeyTools.set(value, storageKey: storageKey)
    }

    /// 逐事件回放 SSE 块的网络桩，同时捕获请求体。
    private final class SSEStreamStub: LLMNetworkProviding, @unchecked Sendable {
        let events: [String]
        let payload: Data
        private let capturedBody = OSAllocatedUnfairLock<Data?>(initialState: nil)

        init(events: [String], payload: Data = Data("{\"output_text\":\"\"}".utf8)) {
            self.events = events
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (payload, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            capturedBody.withLock { $0 = body }
            for event in events {
                guard await onEvent(Data(event.utf8)) else { break }
            }
        }

        func capturedBodyValue() -> Data? {
            capturedBody.withLock { $0 }
        }
    }

    private func makeProvider(stub: SSEStreamStub) -> GoProvider {
        let service = VendorAPIService(networkProvider: stub, maxAttempts: 1)
        return GoProvider(apiService: service)
    }

    private func capturedBody(_ stub: SSEStreamStub) throws -> [String: Any] {
        let body = try #require(stub.capturedBodyValue())
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    // MARK: - Tests

    @Test("流式请求带 stream 标记并逐段回调正文")
    func streamingDeliversIncrementalText() async throws {
        let stub = SSEStreamStub(events: [
            """
            event: response.created
            data: {"type":"response.created","response":{"id":"resp_stream_1"}}
            """,
            """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"你好"}
            """,
            """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"，世界"}
            """,
            """
            event: response.completed
            data: {"type":"response.completed","response":{"id":"resp_stream_1","usage":{"input_tokens":42,"output_tokens":7,"input_tokens_details":{"cached_tokens":30}}}}
            """,
        ])
        let provider = makeProvider(stub: stub)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let pieces = OSAllocatedUnfairLock<[String]>(initialState: [])
        let response = try await provider.streamComplete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "grok-4.5")
        ) { chunk in
            if let piece = chunk.content { pieces.withLock { $0.append(piece) } }
            return ()
        }

        let body = try capturedBody(stub)
        #expect(body["stream"] as? Bool == true, "请求必须带 stream: true")
        #expect(pieces.withLock { $0 } == ["你好", "，世界"], "onChunk 必须收到增量，实际 \(pieces.withLock { $0 })")
        #expect(response.content == "你好，世界")
        #expect(response.responseID == "resp_stream_1")
        #expect(response.inputTokenCount == 42)
        #expect(response.outputTokenCount == 7)
        #expect(response.cachedInputTokenCount == 30)
        #expect(response.cacheTotalInputTokenCount == 42)
    }

    @Test("流式收集 function_call 并按 sanitize 名还原注册名")
    func streamingCollectsFunctionCall() async throws {
        let stub = SSEStreamStub(events: [
            """
            event: response.output_item.done
            data: {"type":"response.output_item.done","item":{"type":"function_call","call_id":"call-9","name":"mcp_weather_lookup","arguments":"{\\"city\\":\\"Tokyo\\"}"}}
            """,
            """
            event: response.completed
            data: {"type":"response.completed","response":{"id":"resp_stream_2","usage":{"input_tokens":10,"output_tokens":3}}}
            """,
        ])
        let provider = makeProvider(stub: stub)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.streamComplete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "查天气")],
                model: "gpt-5.6-luna",
                tools: [
                    LLMFunctionSchema(
                        name: "mcp.weather.lookup",
                        description: "查询",
                        parameters: ["type": "object"]
                    )
                ]
            )
        ) { _ in }

        let body = try capturedBody(stub)
        #expect(body["stream"] as? Bool == true)
        let tools = try #require(body["tools"] as? [[String: Any]])
        #expect(tools.first?["name"] as? String == "mcp_weather_lookup")

        let calls = try #require(response.toolCalls)
        #expect(calls.count == 1)
        #expect(calls[0].id == "call-9")
        #expect(calls[0].name == "mcp.weather.lookup", "流式解析必须按 reverseMap 还原注册名")
        #expect(calls[0].arguments == #"{"city":"Tokyo"}"#)
    }

    @Test("response.failed 必须抛错而不是返回空响应")
    func streamingFailureThrows() async throws {
        let stub = SSEStreamStub(events: [
            """
            event: response.failed
            data: {"type":"response.failed","response":{"error":{"message":"quota exceeded"}}}
            """,
        ])
        let provider = makeProvider(stub: stub)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        do {
            _ = try await provider.streamComplete(
                LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "grok-4.5")
            ) { _ in }
            Issue.record("response.failed 必须抛出错误")
        } catch {
            #expect("\(error)".contains("quota exceeded"), "错误信息必须保留供应商诊断，实际 \(error)")
        }
    }
}
