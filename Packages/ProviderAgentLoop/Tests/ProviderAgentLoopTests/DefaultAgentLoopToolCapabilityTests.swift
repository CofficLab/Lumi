import Foundation
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import ProviderAgentLoop

/// 模型声明 `supportsTools == false` 时，请求不得携带工具 Schema。
///
/// ## 为什么要有这条测试
///
/// `LLMModelInfo.supportsTools` 是模型的能力契约，但请求组装层只检查
/// 会话的 `automationLevel.allowsTools`，完全不读模型的声明。结果是明确
/// 声明不支持工具的模型（MLX 的视觉模型、阿里云的图像模型）仍然收到全部
/// 工具 Schema：既让模型生成它声明不支持的工具调用，又白白消耗工具
/// Schema 的上下文预算，上游还可能直接报协议错误。
@MainActor
@Suite("AgentLoop 按模型能力过滤工具")
struct DefaultAgentLoopToolCapabilityTests {

    // 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
    private typealias ToolCall = KitAgentTool.ToolCall

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

    /// 只提供名称与最小 Schema 的测试工具。
    private final class CapabilityDemoTool: SuperAgentTool, @unchecked Sendable {
        let name = "capability_demo_tool"

        func description(for language: LanguagePreference) -> String { "Demo tool" }
        func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }
        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
        func displayDescription(for arguments: [String: ToolArgument]) -> String { "Demo tool" }
        func execute(arguments: [String: ToolArgument]) async throws -> String { "ok" }
    }

    /// 内存 ToolManager：注册一个工具。
    private final class SingleToolManager: ToolManagerProviding {
        private let tool: any SuperAgentTool

        init(tool: any SuperAgentTool) {
            self.tool = tool
        }

        func allTools() -> [any SuperAgentTool] { [tool] }
        func add(_ tool: any SuperAgentTool, pluginID: String) {}
        func remove(id: String) {}
        func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
            [("test", [tool])]
        }
        func tool(named name: String) -> (any SuperAgentTool)? { name == tool.name ? tool : nil }
        func displayDescription(for toolCall: ToolCall) -> String? { tool.displayDescription(for: [:]) }
        func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { tool.permissionRiskLevel(arguments: [:]) }
        func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
            ToolCallResult(content: "ok")
        }
        func executeBatch(
            _ calls: [ToolCall],
            policy: ToolExecutionPolicy,
            conversationID: UUID,
            turnID: UUID?
        ) async -> [BatchToolResult] {
            var results: [BatchToolResult] = []
            for _ in calls {
                switch policy {
                case .blockAll:
                    results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))
                case .autoExecute:
                    results.append(.executed(ToolCallResult(content: "ok")))
                case .requireApprovalForHighRisk:
                    results.append(.executed(ToolCallResult(content: "ok")))
                }
            }
            return results
        }
        func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
        func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
        func deleteToolCalls(for conversationID: UUID) async {}
    }

    // MARK: - Tests

    @Test("模型声明不支持工具时请求不带工具 Schema")
    func requestOmitsToolsWhenModelDoesNotSupportThem() async throws {
        let provider = ToolCapabilityProvider(modelID: "vision-only", supportsTools: false)
        let llmManager = ToolRecordingLLMManager(provider: provider)
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)

        let loop = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: SingleToolManager(tool: CapabilityDemoTool()),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager()
        )

        _ = try await loop.runTurn(in: conversationID)

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
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)

        let loop = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: SingleToolManager(tool: CapabilityDemoTool()),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager()
        )

        _ = try await loop.runTurn(in: conversationID)

        let request = try #require(llmManager.requests.first, "本轮应发出过一次 LLM 请求")
        #expect(
            request.tools?.map(\.name) == ["capability_demo_tool"],
            "支持工具的模型应正常收到工具 Schema，实际 \(request.tools?.map(\.name) ?? [])"
        )
    }
}
