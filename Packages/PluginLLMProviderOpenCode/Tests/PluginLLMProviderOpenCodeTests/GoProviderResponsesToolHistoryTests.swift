import Foundation
import KitLLM
import os
import Testing
@testable import PluginLLMProviderOpenCode

/// OpenCode Go Responses 路径必须回传工具调用历史（issue #285）。
///
/// ## 为什么要有这条测试
///
/// `grok-4.5` / `gpt-5.6-luna` 走 Responses 协议，响应解析认识
/// `function_call`，但第二轮请求把全部历史序列化成 role+content——
/// assistant 的 toolCalls 与 tool 结果全部丢失，模型看不到上一轮的调用
/// 与输出，工具循环无法重建。
@MainActor
struct GoProviderResponsesToolHistoryTests {

    private static let storageKey = "DevAssistant_ApiKey_OpenCodeGo"

    private static func withIsolatedAPIKey(_ value: String) {
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey.test.\(UUID().uuidString)"
        VendorAPIKeyTools.set(value, storageKey: storageKey)
    }

    /// 捕获请求体的网络桩。
    private final class CapturingNetworkStub: LLMNetworkProviding, @unchecked Sendable {
        let payload: Data
        private let capturedBody = OSAllocatedUnfairLock<Data?>(initialState: nil)

        init(payload: Data) {
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            capturedBody.withLock { $0 = body }
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
        ) async throws {}

        func capturedBodyValue() -> Data? {
            capturedBody.withLock { $0 }
        }
    }

    private func makeProvider(payload: String) -> (GoProvider, CapturingNetworkStub) {
        let network = CapturingNetworkStub(payload: Data(payload.utf8))
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        return (GoProvider(apiService: service), network)
    }

    private func capturedInput(from network: CapturingNetworkStub) throws -> [[String: Any]] {
        let body = try #require(network.capturedBodyValue())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        return try #require(object["input"] as? [[String: Any]])
    }

    private static let responsePayload = """
    {"output_text":"ok","usage":{"input_tokens":10,"output_tokens":1}}
    """

    // MARK: - Tests

    @Test("assistant function_call 与 function_call_output 按 call_id 对应回传")
    func toolHistoryEmittedAsResponsesItems() async throws {
        let (provider, network) = makeProvider(payload: Self.responsePayload)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let request = LLMRequest(
            messages: [
                LLMMessage(role: .user, content: "东京天气如何？"),
                LLMMessage(
                    role: .assistant,
                    content: "",
                    toolCalls: [
                        LLMToolCall(id: "call-1", name: "get_weather", arguments: #"{"city":"Tokyo"}"#)
                    ]
                ),
                LLMMessage(role: .tool, content: "22°C 晴", toolCallID: "call-1"),
                LLMMessage(role: .assistant, content: "东京 22°C，晴。"),
            ],
            model: "grok-4.5",
            tools: [
                LLMFunctionSchema(
                    name: "get_weather",
                    description: "查询天气",
                    parameters: ["type": "object"]
                )
            ]
        )

        _ = try await provider.complete(request)

        let input = try capturedInput(from: network)
        #expect(input.count == 4, "应为 user + function_call + function_call_output + assistant，实际 \(input)")
        #expect(input[0]["role"] as? String == "user")
        #expect(input[1]["type"] as? String == "function_call")
        #expect(input[1]["call_id"] as? String == "call-1")
        #expect(input[1]["name"] as? String == "get_weather")
        #expect(input[1]["arguments"] as? String == #"{"city":"Tokyo"}"#)
        #expect(input[2]["type"] as? String == "function_call_output")
        #expect(input[2]["call_id"] as? String == "call-1")
        #expect(input[2]["output"] as? String == "22°C 晴")
        #expect(input[3]["role"] as? String == "assistant")
        #expect(input[3]["content"] as? String == "东京 22°C，晴。")
    }

    @Test("带正文的 assistant 历史保留消息项，工具调用名写回 sanitize 名")
    func assistantTextKeptAndNamesSanitized() async throws {
        let (provider, network) = makeProvider(payload: Self.responsePayload)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let request = LLMRequest(
            messages: [
                LLMMessage(
                    role: .assistant,
                    content: "我先查一下。",
                    toolCalls: [
                        LLMToolCall(id: "call-2", name: "mcp.weather.lookup", arguments: "{}")
                    ]
                ),
                LLMMessage(role: .tool, content: "ok", toolCallID: "call-2"),
            ],
            model: "gpt-5.6-luna",
            tools: [
                LLMFunctionSchema(
                    name: "mcp.weather.lookup",
                    description: "查询",
                    parameters: ["type": "object"]
                )
            ]
        )

        _ = try await provider.complete(request)

        let input = try capturedInput(from: network)
        #expect(input.count == 3, "assistant 正文 + function_call + function_call_output，实际 \(input)")
        #expect(input[0]["role"] as? String == "assistant")
        #expect(input[0]["content"] as? String == "我先查一下。")
        #expect(input[1]["type"] as? String == "function_call")
        // 与 tools 定义相同的 sanitize 规则：点号转下划线。
        #expect(input[1]["name"] as? String == "mcp_weather_lookup")
        #expect(input[1]["call_id"] as? String == "call-2")
        #expect(input[2]["type"] as? String == "function_call_output")
        #expect(input[2]["call_id"] as? String == "call-2")
    }

    @Test("无工具历史保持 role+content 序列化不变")
    func plainHistoryUnchanged() async throws {
        let (provider, network) = makeProvider(payload: Self.responsePayload)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        _ = try await provider.complete(
            LLMRequest(
                messages: [
                    LLMMessage(role: .user, content: "hi"),
                    LLMMessage(role: .assistant, content: "hello"),
                ],
                model: "grok-4.5"
            )
        )

        let input = try capturedInput(from: network)
        #expect(input.count == 2)
        #expect(input[0]["role"] as? String == "user")
        #expect(input[0]["content"] as? String == "hi")
        #expect(input[1]["role"] as? String == "assistant")
        #expect(input[1]["content"] as? String == "hello")
    }
}
