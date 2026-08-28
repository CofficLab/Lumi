import Combine
import Foundation
import Testing
import KitAgentTool
import ProviderMessage
import KitLLM
import ProviderConversation
import ProviderLLMManager
import ProviderToolManager
import ProviderMessageStreaming
@testable import ProviderAgentLoop

@Suite("ProviderAgentLoop")
@MainActor
struct ProviderAgentLoopTests {
    // 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
    private typealias ToolCall = KitAgentTool.ToolCall

    @MainActor
    private final class TestLLMProvider: SuperLLMProvider {
        nonisolated let providerID = "test"
        nonisolated let providerInfo = LLMProviderInfo(id: "test", displayName: "Test", defaultModel: "", models: [], isLocal: true)
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "from provider", model: request.model)
        }
    }

    /// 测试用 LLMManaging：转发到脚本化 provider。
    @MainActor
    private final class TestLLMManager: LLMManaging {
        var provider: any SuperLLMProvider

        init(provider: any SuperLLMProvider) {
            self.provider = provider
        }

        var providerID: String { "test-manager" }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: "test-manager", displayName: "Test Manager", defaultModel: "", models: [], isLocal: true)
        }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            try await provider.complete(request)
        }

        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { provider }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { "test-manager" }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?) {}
    }

    /// 内存会话管理器（最小实现，默认 build 自动化级别）。
    @MainActor
    private final class TestConversationManager: ConversationManaging {
        var dataDirectory: URL { URL(fileURLWithPath: "/tmp") }
        var conversations: [LumiConversationSummary] = []
        var selectedConversationID: UUID?
        var currentTitle: String = "No conversation"
        var globalVerbosity: LumiResponseVerbosity = .standard
        var globalReasoningEffort: LumiReasoningEffort?
        var globalAutomationLevel: LumiAutomationLevel = .build
        var globalLanguage: LumiConversationLanguage = .chinese

        @Published var tick = false

        func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID { UUID() }
        func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?, parentConversationID: UUID?) throws -> UUID { UUID() }
        func selectConversation(id: UUID) { selectedConversationID = id }
        func deselectConversation() { selectedConversationID = nil }
        func deleteConversation(id: UUID) {}
        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
        func markConversationActive(id: UUID, messageDate: Date) {}
        func isSending(for conversationID: UUID?) -> Bool { false }
        func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
            NoopSelectedConversationObserverHandle()
        }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
        func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) { globalVerbosity = verbosity }
        func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { globalVerbosity }
        func setGlobalReasoningEffort(_ reasoningEffort: LumiReasoningEffort?) { globalReasoningEffort = reasoningEffort }
        func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort { globalReasoningEffort ?? .defaultEffort }
        func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? { globalReasoningEffort }
        func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {}
        func clearReasoningEffort(for conversationID: UUID?) {}
        func setGlobalAutomationLevel(_ automationLevel: LumiAutomationLevel) { globalAutomationLevel = automationLevel }
        func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { globalAutomationLevel }
        func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
        func setGlobalLanguage(_ language: LumiConversationLanguage) { globalLanguage = language }
        func language(for conversationID: UUID?) -> LumiConversationLanguage { globalLanguage }
        func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
    }

    /// 内存消息流 store。
    @MainActor
    private final class TestStreaming: MessageStreamingProviding {
        func streamingMessage(for conversationID: UUID) -> Message? { nil }
        func stage(for conversationID: UUID) -> MessageStreamingStage { .idle }
        func start(conversationID: UUID) {}
        func appendContent(_ content: String, conversationID: UUID) {}
        func appendThinking(_ content: String, conversationID: UUID) {}
        func end(conversationID: UUID) {}
    }

    @MainActor
    private final class NoopToolManager: ToolManagerProviding {
        func allTools() -> [any SuperAgentTool] { [] }
        func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
        func tool(named name: String) -> (any SuperAgentTool)? { nil }
        func add(_ tool: any SuperAgentTool, pluginID: String) {}
        func remove(id: String) {}
        func displayDescription(for toolCall: ToolCall) -> String? { nil }
        func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
        func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
            ToolCallResult(content: "noop")
        }
        func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
        func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
        func deleteToolCalls(for conversationID: UUID) async {}
    }

    /// 组装测试用 Loop（构造注入全依赖）。
    private func makeLoop(
        messages: any MessageManaging,
        provider: any SuperLLMProvider = TestLLMProvider()
    ) -> DefaultAgentLoopProvider {
        DefaultAgentLoopProvider(
            messages: messages,
            llmManager: TestLLMManager(provider: provider),
            toolManager: NoopToolManager(),
            streaming: TestStreaming(),
            conversations: TestConversationManager()
        )
    }

    @Test("Loop 通过 LLM Provider 生成 assistant 消息并更新状态")
    func runsTurn() async throws {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = makeLoop(messages: messages)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "from provider")
        #expect(loop.state(for: conversationID) == .completed)
    }

    @Test("Loop 通过 LLM Provider 生成 assistant 消息")
    func runsWithLLMProvider() async throws {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = makeLoop(messages: messages, provider: TestLLMProvider())

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "from provider")
    }

    @Test("创建 Loop 时依赖全部注入，直接可用")
    func constructorInjection() async throws {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = makeLoop(messages: messages)
        // 构造注入后无需任何 setter 即可运行。
        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "from provider")
    }

    @Test("resumeTurn 无挂起点时抛出 invalidResumeRequest")
    func resumeTurnWithoutSuspensionThrows() async throws {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let loop = makeLoop(messages: messages)
        do {
            _ = try await loop.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(suspensionID: "nope", answer: "yes")
            )
            Issue.record("应当抛出 invalidResumeRequest")
        } catch {
            #expect(error is AgentLoopError)
        }
    }
}