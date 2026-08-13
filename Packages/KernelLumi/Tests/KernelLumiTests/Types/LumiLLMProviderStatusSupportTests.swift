import Foundation
import Testing
@testable import KernelLumi

/// `LumiLLMProviderStatusSupport` 的契约测试。
///
/// 模块对应:`Sources/KernelLumi/Types/LLM/LumiLLMProviderStatus.swift`。
///
/// 回归背景:`statusForRemoteAPIKeyProvider` 曾经回调 `provider.providerStatus()`,
/// 而几乎每个 provider 的 `providerStatus()` 又委托给它,形成无限递归。这里锁定:
/// 1. 判定只依赖 `hasApiKey()`,不再回调 `providerStatus()`(用计数器验证)。
/// 2. 已配置 Key → nil(健康);未配置 → blocking `.warning`。
/// 3. `missingAPIKeyStatus` 把 `providerName` 插值进 message(原为死参数)。
@Suite("LumiLLMProviderStatusSupport")
struct LumiLLMProviderStatusSupportTests {

    /// 只暴露 `hasApiKey()` 与 `info`,并能统计 `providerStatus()` 被调用次数的 mock。
    ///
    /// 注意:`providerStatus()` 在这里**故意抛出 fatalError**,而不是回delegate 给 helper ——
    /// 一旦 helper 又去回调它,测试会立即崩溃(比单纯计数更硬地锁住「不准递归」契约)。
    private final class MockProvider: LumiLLMProvider, @unchecked Sendable {
        static let info = LumiLLMProviderInfo(
            id: "mock-remote",
            displayName: "Mock Remote",
            defaultModel: "mock-model",
            availableModels: ["mock-model"],
            websiteURL: URL(string: "https://example.com")!
        )

        let apiKeyConfigured: Bool
        /// 统计 `providerStatus()` 被调用了几次 —— 应恒为 0(helper 不得回调)。
        var providerStatusCallCount = 0

        init(apiKeyConfigured: Bool) {
            self.apiKeyConfigured = apiKeyConfigured
        }

        func hasApiKey() -> Bool { apiKeyConfigured }
        func providerStatus() -> LumiLLMProviderStatus? {
            providerStatusCallCount += 1
            // 若 helper 正确,永远不会走到这里。走到这里说明发生了递归,直接失败。
            Issue.record("statusForRemoteAPIKeyProvider 不应回调 providerStatus() —— 检测到递归")
            return nil
        }

        // 余下协议成员:helper 路径不会调到,返回最小默认值即可。
        func lumiResolveAPIKey() throws -> String { "" }
        func getApiKey() -> String { "" }
        func setApiKey(_ apiKey: String) {}
        func removeApiKey() {}
        func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
            LumiChatMessage(conversationID: UUID(), role: .assistant, content: "")
        }
        func sendStreaming(
            _ request: LumiLLMRequest,
            onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
        ) async throws -> LumiChatMessage {
            LumiChatMessage(conversationID: UUID(), role: .assistant, content: "")
        }
        func checkAvailability(model: String) async -> LumiModelAvailabilityResult { .available }
        func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
            .nonRetryable
        }
        func errorRenderKind(for error: Error) -> String? { nil }
        func makeErrorMessage(
            conversationID: UUID,
            request: LumiLLMRequest,
            error: Error,
            disposition: LumiLLMErrorDisposition
        ) -> LumiChatMessage {
            LumiChatMessage(conversationID: conversationID, role: .assistant, content: "")
        }
    }

    @Test("已配置 API Key 时返回 nil(健康)")
    func returnsNilWhenAPIKeyConfigured() {
        let provider = MockProvider(apiKeyConfigured: true)
        let status = LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: provider)
        #expect(status == nil)
        #expect(provider.providerStatusCallCount == 0, "不得回调 providerStatus()")
    }

    @Test("未配置 API Key 时返回 blocking warning")
    func returnsBlockingWarningWhenAPIKeyMissing() throws {
        let provider = MockProvider(apiKeyConfigured: false)
        let resolved = LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: provider)
        let status = try #require(resolved)
        #expect(status.level == .warning)
        #expect(status.isBlocking == true)
        #expect(provider.providerStatusCallCount == 0, "不得回调 providerStatus()")
    }

    @Test("missingAPIKeyStatus 把 provider 名称插值进消息")
    func missingAPIKeyStatusIncludesProviderName() throws {
        let provider = MockProvider(apiKeyConfigured: false)
        let resolved = LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: provider)
        let status = try #require(resolved)
        #expect(status.message.contains("Mock Remote"),
                "消息应包含 provider 的 displayName,实际:\(status.message)")
    }

    @Test("hasConfiguredAPIKey 与 hasApiKey 一致")
    func hasConfiguredAPIKeyMirrorsHasApiKey() {
        let configured = MockProvider(apiKeyConfigured: true)
        let missing = MockProvider(apiKeyConfigured: false)
        #expect(LumiLLMProviderStatusSupport.hasConfiguredAPIKey(provider: configured) == true)
        #expect(LumiLLMProviderStatusSupport.hasConfiguredAPIKey(provider: missing) == false)
    }
}
