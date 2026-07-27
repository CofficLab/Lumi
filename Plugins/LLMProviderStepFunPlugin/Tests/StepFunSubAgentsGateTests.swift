// NOTE: This test file is currently NOT executable under `swift test` because
// `PluginLLMProviderStepFunTests.swift` in the same target references
// `StepFunPlugin.id` / `StepFunPlugin.displayName` etc. as static members,
// but `StepFunPlugin` (and the `LumiPlugin` protocol) only exposes `info`.
// That's a pre-existing SPM compilation issue, unrelated to this commit.
//
// Once that's fixed (either by adding `id`/`displayName`/... extensions to
// `LumiPlugin` or by switching the existing test to `StepFunPlugin.info.id`),
// the tests below will run and protect the gate contract end-to-end.
//
// In the meantime, the same gate semantics are covered by:
// - `LumiLLMProviderStatusBlockingTests` (4 cases for `isBlocking`)
// - `ProviderAvailabilityGateTests` (4 cases for the combined `!= true` check)
//
// Both live in `Packages/LumiCoreKit/Tests/LumiCoreKitTests/LumiLLMProviderStatusBlockingTests.swift`.

import Foundation
import Testing
import LumiKernel
@testable import LLMProviderStepFunPlugin

/// 测试 `StepFunPlugin.subAgents(context:)` 的 Provider 可用性 gate 行为。
///
/// 这是端到端契约测试，构造真实的 `LumiPluginContext`，注入 mock chatService +
/// mock provider（两者都 stub 自协议），确保：
/// - Provider 不可用（status nil 不阻塞 OR 全是 .info）→ 返回全部 5 个 sub-agent
/// - Provider 可用性告警（.warning / .error）→ 返回空数组（主 LLM 看不到工具）
/// - chatService 缺失 / provider 找不到 → 返回空数组
@Suite struct StepFunSubAgentsGateTests {

    // MARK: - Mock 基础设施

    /// 可控 `providerStatus()` 的 mock provider。
    private final class MockStepFunProvider: LumiLLMProvider, @unchecked Sendable {
        static let info = LumiLLMProviderInfo(
            id: "com.coffic.lumi.plugin.llm-provider.stepfun",
            displayName: "StepFun (Mock)",
            defaultModel: "step-3.7-flash",
            availableModels: ["step-3.7-flash"],
            websiteURL: URL(string: "https://example.com")!
        )

        let statusToReturn: LumiLLMProviderStatus?

        init(statusToReturn: LumiLLMProviderStatus?) {
            self.statusToReturn = statusToReturn
        }

        func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
            throw NSError(domain: "MockProvider", code: 0)
        }

        func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
            .available
        }

        func providerStatus() -> LumiLLMProviderStatus? {
            statusToReturn
        }
    }

    /// 只 stub `provider(forID:)`，其它方法跟 `SubAgentMockChatService` 一样返回空/mock。
    private final class GateMockChatService: LumiChatServicing, @unchecked Sendable {
        let providerToReturn: (any LumiLLMProvider)?

        init(providerToReturn: (any LumiLLMProvider)?) {
            self.providerToReturn = providerToReturn
        }

        // 仅暴露 provider(forID:) 的实质逻辑，其余接口为满足协议强制实现。
        func provider(forID id: String) -> (any LumiLLMProvider)? { providerToReturn }

        // 余下方法：返回最小的"无害默认值"，subAgents gate 路径不会调到。
        var conversations: [LumiConversationSummary] { [] }
        var selectedConversationID: UUID? { nil }
        var providerInfos: [LumiLLMProviderInfo] { [] }
        var selectedProviderID: String? { nil }
        var selectedModel: String? { nil }
        var messageRenderers: [LumiMessageRendererItem] { [] }
        var revision: Int { 0 }
        var pendingMessages: [LumiPendingMessage] { [] }
        var routingMode: LumiModelRoutingMode { .auto }
        var pendingToolConfirmation: LumiPendingToolConfirmation? { nil }
        func isSending(for conversationID: UUID?) -> Bool { false }
        @discardableResult func createConversation(title: String?) -> UUID { UUID() }
        @discardableResult func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
        func selectConversation(id: UUID) {}
        func deleteConversation(id: UUID) {}
        @discardableResult func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }
        @discardableResult func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { true }
        func selectProvider(id: String, model: String?) {}
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func setRoutingMode(_ mode: LumiModelRoutingMode) {}
        func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
        func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
        func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
        func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
        func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
        func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
        func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
        func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
        func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
        func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
        func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
        func enqueueText(_ text: String, in conversationID: UUID?) {}
        func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
        func continueTurn(in conversationID: UUID) {}
        func cancelSending(for conversationID: UUID?) {}
        func approvePendingTool() {}
        func rejectPendingTool() {}
        func removePendingMessage(id: UUID) {}
        func deleteMessage(id: UUID, in conversationID: UUID) {}
        func resendMessage(id: UUID, in conversationID: UUID) async {}
        func send(_ text: String, in conversationID: UUID?) async {}
        func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
            LumiChatMessage(conversationID: conversationID, role: .assistant, content: "")
        }
        func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
            LumiConversationContextUsage(currentTokens: 0, limit: 0)
        }
    }

    /// 构造一个把 `chatService` 注入到 `LumiPluginContext` 的辅助方法。
    private static func makeContext(chatService: any LumiChatServicing) -> LumiPluginContext {
        let deps = LumiPluginDependencies { d in
            d.register((any LumiChatServicing).self, chatService)
        }
        return LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test",
            dependencies: deps
        )
    }

    // MARK: - 测试用例

    @MainActor
    @Test func subAgents_registered_whenProviderHealthy() {
        // Provider 健康（status == nil）
        let provider = MockStepFunProvider(statusToReturn: nil)
        let chat = GateMockChatService(providerToReturn: provider)
        let context = Self.makeContext(chatService: chat)

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.count == 5,
                "Provider 健康时应注册全部 5 个 sub-agent（git/test/review/doc/bug）")
        #expect(subAgents.map(\.id).sorted() == [
            "bug-fixer", "code-reviewer", "doc-writer", "git-commit-writer", "test-writer"
        ])
    }

    @MainActor
    @Test func subAgents_registered_whenProviderStatusIsInfo() {
        // status 为 .info —— 通常是通知，不应阻塞
        let status = LumiLLMProviderStatus(message: "release notes", level: .info)
        let provider = MockStepFunProvider(statusToReturn: status)
        let chat = GateMockChatService(providerToReturn: provider)
        let context = Self.makeContext(chatService: chat)

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.count == 5, ".info 视为可用，应注册全部 sub-agent")
    }

    @MainActor
    @Test func subAgents_gated_whenApiKeyMissing() {
        // 模拟真实场景：API Key 未配置（StepFunProvider 的 .missingAPIKeyStatus 走 .warning）
        let status = LumiLLMProviderStatusSupport.missingAPIKeyStatus(providerName: "StepFun")
        let provider = MockStepFunProvider(statusToReturn: status)
        let chat = GateMockChatService(providerToReturn: provider)
        let context = Self.makeContext(chatService: chat)

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.isEmpty,
                "API Key 缺失（.warning）时必须 gate，否则每个 delegate_* 调用都会失败")
    }

    @MainActor
    @Test func subAgents_gated_whenProviderError() {
        // .error 级别（类似 MLX 在 Intel Mac 的「完全不可用」）
        let status = LumiLLMProviderStatus(message: "platform unsupported", level: .error)
        let provider = MockStepFunProvider(statusToReturn: status)
        let chat = GateMockChatService(providerToReturn: provider)
        let context = Self.makeContext(chatService: chat)

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.isEmpty, ".error 必须 gate")
    }

    @MainActor
    @Test func subAgents_gated_whenProviderInstanceMissing() {
        // ChatService 找不到 provider 实例（plugin 加载时序异常场景）
        let chat = GateMockChatService(providerToReturn: nil)
        let context = Self.makeContext(chatService: chat)

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.isEmpty, "Provider 实例缺失时应 gate")
    }

    @MainActor
    @Test func subAgents_gated_whenChatServiceMissing() {
        // context 中完全不注入 ChatService（极早期阶段，例如 plugin registry 启动前）
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )

        let subAgents = StepFunPlugin.subAgents(context: context)
        #expect(subAgents.isEmpty, "缺 ChatService 时应保守 gate")
    }
}
