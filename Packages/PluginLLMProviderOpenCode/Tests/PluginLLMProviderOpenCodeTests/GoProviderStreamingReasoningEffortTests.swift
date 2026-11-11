import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderOpenCode

/// OpenCode Go 的流式请求必须带上选定的 Reasoning Effort。
///
/// ## 为什么要有这条测试
///
/// Responses 路径会带上 `request.reasoningEffort`，但 Chat Completions 与
/// Anthropic 的流式分支重建 `LLMConfig` 时没把这个字段放进去。
///
/// 结果是：对话里显示 **High**，实际发出的流式请求既没有
/// `reasoning_effort`，也没有启用 Anthropic 的 `thinking` 配置——用户
/// 拿到的是供应商的默认推理行为，而界面完全看不出来。
@MainActor
struct GoProviderStreamingReasoningEffortTests {

    private static let storageKey = "DevAssistant_ApiKey_OpenCodeGo"

    /// 把 API Key 写入**一次性**的 Keychain service，绝不碰生产 service。
    private static func withIsolatedAPIKey(_ value: String) {
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey.test.\(UUID().uuidString)"
        VendorAPIKeyTools.set(value, storageKey: storageKey)
    }

    /// 记录流式请求体的网络桩。
    ///
    /// 按 URL 路径发出对应协议的结束事件：Chat Completions 用
    /// `finish_reason`，Anthropic 用 `message_stop`。
    private final class StreamingBodyRecorder: LLMNetworkProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var storedBodies: [Data] = []

        var bodies: [Data] { lock.withLock { storedBodies } }

        /// 最近一次请求体解析出的 JSON 对象。
        var lastBodyJSON: [String: Any] {
            guard let body = bodies.last,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return [:]
            }
            return object
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            throw StubError.unexpectedNonStreamingRequest
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {
            lock.withLock { storedBodies.append(body) }
            let isAnthropic = request.url?.path.hasSuffix("/messages") == true
            let event: Data
            if isAnthropic {
                event = Data("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n".utf8)
            } else {
                event = Data("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n".utf8)
            }
            _ = await onEvent(event)
        }
    }

    private enum StubError: Error {
        case unexpectedNonStreamingRequest
    }

    // MARK: - Tests

    @Test("Chat Completions 流式请求带上 reasoning_effort")
    func openAIStreamKeepsReasoningEffort() async throws {
        let network = StreamingBodyRecorder()
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = GoProvider(apiService: service)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        _ = try await provider.streamComplete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "deepseek-v4-flash",
                reasoningEffort: "high"
            ),
            onChunk: { _ in }
        )

        #expect(
            network.lastBodyJSON["reasoning_effort"] as? String == "high",
            "Chat Completions 流式请求丢失了 reasoning effort，实际 \(network.lastBodyJSON)"
        )
    }

    @Test("Anthropic 流式请求带上启用状态的 thinking 配置")
    func anthropicStreamKeepsReasoningEffort() async throws {
        let network = StreamingBodyRecorder()
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = GoProvider(apiService: service)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        _ = try await provider.streamComplete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "qwen3.7-plus",
                reasoningEffort: "high"
            ),
            onChunk: { _ in }
        )

        let thinking = network.lastBodyJSON["thinking"] as? [String: Any]
        #expect(
            thinking?["type"] as? String == "enabled",
            "Anthropic 流式请求丢失了 thinking 配置，实际 \(network.lastBodyJSON)"
        )
    }

    @Test("未指定推理档位时不带 reasoning_effort")
    func streamWithoutReasoningEffortOmitsIt() async throws {
        let network = StreamingBodyRecorder()
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = GoProvider(apiService: service)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        _ = try await provider.streamComplete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "deepseek-v4-flash"
            ),
            onChunk: { _ in }
        )

        #expect(
            network.lastBodyJSON["reasoning_effort"] == nil,
            "未指定档位时不应下发 reasoning_effort"
        )
    }
}
