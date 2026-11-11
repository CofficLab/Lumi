import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderOpenCode

/// OpenCode Go 的 Responses 路径必须保留缓存 token 统计。
///
/// ## 为什么要有这条测试
///
/// `grok-4.5` / `gpt-5.6-luna` 走 Responses 协议，而该分支的 `LLMResponse`
/// 初始化只填了输入 / 输出 token，所有缓存字段都是 `nil`。Responses 的
/// 标准 usage 把缓存命中写在 `input_tokens_details.cached_tokens` 里，
/// 共享的 OpenAI 适配器已经认识这个形态。
///
/// 缓存字段为 `nil` 时：助手消息持久化的缓存字段也是 `nil`，缓存命中率
/// 的采样器要求「命中数 + 总量」齐备，于是**每一轮 Responses 请求都被
/// 静默排除在统计之外**——用户看到的命中率永远没有这部分数据。
@MainActor
struct GoProviderResponsesCacheUsageTests {

    private static let storageKey = "DevAssistant_ApiKey_OpenCodeGo"

    /// 把 API Key 写入**一次性**的 Keychain service，绝不碰生产 service。
    private static func withIsolatedAPIKey(_ value: String) {
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey.test.\(UUID().uuidString)"
        VendorAPIKeyTools.set(value, storageKey: storageKey)
    }

    /// 返回固定 JSON 的网络桩。
    private final class ResponsesNetworkStub: LLMNetworkProviding, @unchecked Sendable {
        let payload: Data

        init(payload: Data) {
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
        ) async throws {}
    }

    private func makeProvider(payload: String) -> GoProvider {
        let network = ResponsesNetworkStub(payload: Data(payload.utf8))
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        return GoProvider(apiService: service)
    }

    // MARK: - Tests

    @Test("Responses 路径保留 input_tokens_details.cached_tokens")
    func responsesPreservesCachedInputTokens() async throws {
        let provider = makeProvider(payload: """
        {"output_text":"ok","usage":{"input_tokens":120,"output_tokens":20,\
        "input_tokens_details":{"cached_tokens":80}}}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "grok-4.5"
            )
        )

        #expect(response.inputTokenCount == 120)
        #expect(response.outputTokenCount == 20)
        #expect(
            response.cachedInputTokenCount == 80,
            "缓存命中数被丢弃，实际 \(String(describing: response.cachedInputTokenCount))"
        )
        #expect(
            response.cacheTotalInputTokenCount == 120,
            "总输入缺失，缓存命中率采样器会因此拒绝该轮次"
        )
    }

    @Test("Responses 路径保留 cache_write_tokens")
    func responsesPreservesCacheWriteTokens() async throws {
        let provider = makeProvider(payload: """
        {"output_text":"ok","usage":{"input_tokens":100,"output_tokens":10,\
        "input_tokens_details":{"cache_write_tokens":30}}}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "gpt-5.6-luna"
            )
        )

        #expect(response.cacheWriteInputTokenCount == 30)
    }

    @Test("没有缓存信息时缓存字段保持 nil")
    func responsesWithoutCacheInfoLeavesCacheFieldsNil() async throws {
        let provider = makeProvider(payload: """
        {"output_text":"ok","usage":{"input_tokens":50,"output_tokens":5}}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(
            LLMRequest(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "grok-4.5"
            )
        )

        #expect(response.inputTokenCount == 50)
        #expect(response.cachedInputTokenCount == nil)
        #expect(response.cacheWriteInputTokenCount == nil)
    }
}
