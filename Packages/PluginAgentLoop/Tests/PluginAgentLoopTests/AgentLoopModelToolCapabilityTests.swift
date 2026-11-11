import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 模型声明 `supportsTools == false` 时，本次请求不得携带工具 Schema。
///
/// ## 为什么要有这条测试
///
/// `LLMModelInfo.supportsTools` 明确定义为「是否支持工具调用」，但请求
/// 组装层只检查会话的 `automationLevel.allowsTools`，完全不读模型的
/// 能力声明。结果是明确声明不支持工具的模型（例如 MLX 的
/// `Qwen3-VL-2B-Instruct-4bit`、阿里云的图像模型）仍然收到全部工具
/// Schema：
/// - 模型被要求理解并生成它声明不支持的工具调用；
/// - 工具 Schema 白白消耗上下文预算；
/// - 上游可能直接报协议或能力错误。
///
/// 正确行为：解析当前模型路由后，若 `modelInfo.supportsTools == false`，
/// 本次请求省略工具 Schema。
@MainActor
@Suite("AgentLoop 按模型能力过滤工具")
struct AgentLoopModelToolCapabilityTests {

    /// 记录收到的请求的 LLM 管理器替身。
    private final class ToolRecordingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
        private let provider: ToolCapabilityProvider
        private(set) var requests: [LLMRequest] = []

        init(provider: ToolCapabilityProvider) {
            self.provider = provider
        }

        var providerID: String { Self.managerProviderID }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: providerID, displayName: "Test Manager", defaultModel: "", models: [], isLocal: true)
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
        }

        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
        }

        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { id == provider.providerInfo.id ? provider : nil }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { provider.providerInfo.id }
        var selectedModel: String? { provider.providerInfo.defaultModel }
        func models(for providerID: String) -> [String] { provider.providerInfo.modelIDs }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    }

    /// 声明了工具能力的供应商替身。
    private final class ToolCapabilityProvider: SuperLLMProvider {
        let providerInfo: LLMProviderInfo

        init(modelID: String, supportsTools: Bool) {
            providerInfo = LLMProviderInfo(
                id: "tool-capability-provider",
                displayName: "Tool Capability Provider",
                defaultModel: modelID,
                models: [LLMModelInfo(id: modelID, supportsTools: supportsTools)],
                isLocal: true
            )
        }

        var providerID: String { providerInfo.id }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "ok", model: request.model)
        }
    }

    /// 构造一个最小可用的 `AgentLoopManager`（不触碰网络与磁盘）。
    private func makeManager(llmManager: any LLMManaging) -> AgentLoopManager {
        let messageStore = DefaultMessageManager()
        let toolManager = DefaultToolManagerProviding()
        // 注册一个真实工具：没有工具时「请求不带 Schema」无法证明是
        // 能力过滤生效，而不是本来就没有工具可发。
        toolManager.add(CapabilityDemoTool(), pluginID: "test")
        return AgentLoopManager(
            messages: messageStore,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messageStore)
        )
    }

    // MARK: - Tests

    @Test("模型声明不支持工具时请求不带工具 Schema")
    func requestOmitsToolsWhenModelDoesNotSupportThem() async throws {
        let provider = ToolCapabilityProvider(modelID: "vision-only", supportsTools: false)
        let llmManager = ToolRecordingLLMManager(provider: provider)
        let manager = makeManager(llmManager: llmManager)

        let conversationID = UUID()
        try await manager.runTurn(in: conversationID)

        let request = try #require(llmManager.requests.first, "本轮应发出过一次 LLM 请求")
        #expect(
            request.tools == nil || request.tools?.isEmpty == true,
            "不支持工具的模型不应收到工具 Schema，实际 \(request.tools?.map(\.name) ?? [])"
        )
    }

    @Test("模型声明支持工具时请求仍带工具 Schema")
    func requestKeepsToolsWhenModelSupportsThem() async throws {
        let provider = ToolCapabilityProvider(modelID: "tool-capable", supportsTools: true)
        let llmManager = ToolRecordingLLMManager(provider: provider)
        let manager = makeManager(llmManager: llmManager)

        let conversationID = UUID()
        try await manager.runTurn(in: conversationID)

        let request = try #require(llmManager.requests.first, "本轮应发出过一次 LLM 请求")
        #expect(
            request.tools?.map(\.name) == ["capability_demo_tool"],
            "支持工具的模型应正常收到工具 Schema，实际 \(request.tools?.map(\.name) ?? [])"
        )
    }
}

/// 测试用工具：只提供名称与最小 Schema。
private struct CapabilityDemoTool: SuperAgentTool {
    let name = "capability_demo_tool"

    func description(for language: LanguagePreference) -> String { "Demo tool" }

    func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Demo tool" }
}
