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

@Suite("AgentLoop 完整回合循环")
@MainActor
struct AgentLoopFullLoopTests {

    // 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
    private typealias ToolCall = KitAgentTool.ToolCall

    // MARK: - Test Doubles

    /// 可编排响应序列的 LLM Provider：按调用次数依次返回预设响应。
    @MainActor
    private final class ScriptedLLMProvider: SuperLLMProvider {
        nonisolated let providerID = "scripted"
        nonisolated let providerInfo = LLMProviderInfo(id: "scripted", displayName: "Scripted", defaultModel: "", models: [], isLocal: true)
        var responses: [LLMResponse]
        var receivedRequests: [LLMRequest] = []

        init(responses: [LLMResponse]) {
            self.responses = responses
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            receivedRequests.append(request)
            guard !responses.isEmpty else { return LLMResponse(content: "") }
            return responses.removeFirst()
        }
    }

    /// 包一层 LLMManaging：测试用管理器，转发到脚本化 provider。
    /// 同时实现 LLMStreamingProviding：底层 provider 支持流式时转发，
    /// 以验证 AgentLoop 的流式优先路径。
    @MainActor
    private final class ScriptedLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
        var provider: any SuperLLMProvider

        init(provider: any SuperLLMProvider) {
            self.provider = provider
        }

        var providerID: String { "scripted-manager" }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: "scripted-manager", displayName: "Scripted Manager", defaultModel: "", models: [], isLocal: true)
        }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            try await provider.complete(request)
        }
        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            if let streamingProvider = provider as? any LLMStreamingProviding {
                return try await streamingProvider.streamComplete(request, onChunk: onChunk)
            }
            return try await complete(request)
        }

        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { provider }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { "scripted-manager" }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?) {}
    }

    /// 可编程工具：返回预设结果。
    private final class ScriptedTool: SuperAgentTool, @unchecked Sendable {
        let name: String
        let risk: CommandRiskLevel
        var result: ToolCallResult
        var executionCount = 0

        init(name: String, risk: CommandRiskLevel = .safe, result: ToolCallResult = ToolCallResult(content: "ok")) {
            self.name = name
            self.risk = risk
            self.result = result
        }

        func description(for language: LanguagePreference) -> String { "Tool \(name)" }
        func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { risk }
        func displayDescription(for arguments: [String: ToolArgument]) -> String { "执行 \(name)" }
        func execute(arguments: [String: ToolArgument]) async throws -> String {
            executionCount += 1
            return result.content
        }
    }

    /// 内存 ToolManager（对齐协议）。
    @MainActor
    private final class TestToolManager: ToolManagerProviding {
        private var tools: [String: any SuperAgentTool] = [:]
        private var order: [String] = []
        private var observers: [UUID: (ToolManagerEvent) -> Void] = [:]

        private final class ObserverHandle: ToolManagerObserverHandle {
            private var cancellation: (() -> Void)?
            init(_ cancellation: @escaping () -> Void) { self.cancellation = cancellation }
            func cancel() { cancellation?(); cancellation = nil }
        }

        @discardableResult
        func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle {
            let id = UUID()
            observers[id] = callback
            return ObserverHandle { [weak self] in self?.observers.removeValue(forKey: id) }
        }

        func allTools() -> [any SuperAgentTool] { order.compactMap { tools[$0] } }
        func add(_ tool: any SuperAgentTool, pluginID: String) {
            if tools[tool.name] == nil { order.append(tool.name) }
            tools[tool.name] = tool
        }
        func remove(id: String) {
            tools.removeValue(forKey: id)
            order.removeAll { $0 == id }
        }
        func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] {
            [("test", allTools())]
        }
        func tool(named name: String) -> (any SuperAgentTool)? { tools[name] }
        func displayDescription(for toolCall: ToolCall) -> String? {
            tools[toolCall.name]?.displayDescription(for: [:])
        }
        func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
            tools[toolCall.name]?.permissionRiskLevel(arguments: [:])
        }
        func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
            guard let tool = tools[toolCall.name] else {
                return ToolCallResult(content: "unknown tool", isError: true)
            }
            do {
                return try await tool.executeResult(arguments: [:])
            } catch {
                return ToolCallResult(content: String(describing: error), isError: true)
            }
        }
        func executeBatch(_ calls: [ToolCall], policy: ToolExecutionPolicy, conversationID: UUID, turnID: UUID?) async -> [BatchToolResult] {
            var results: [BatchToolResult] = []
            for call in calls {
                switch policy {
                case .blockAll:
                    results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))
                case .autoExecute:
                    results.append(.executed(await execute(call, conversationID: conversationID, turnID: turnID)))
                case .requireApprovalForHighRisk:
                    let risk = riskLevel(for: call) ?? .high
                    if risk.requiresPermission {
                        let payload = "{\"toolCallId\":\"approval:\(call.id)\",\"kind\":\"permission\",\"question\":\"需要确认\",\"options\":[\"允许\",\"拒绝\"],\"mode\":\"yes_no\"}"
                        results.append(.needsUserResponse(payload: payload))
                    } else {
                        results.append(.executed(await execute(call, conversationID: conversationID, turnID: turnID)))
                    }
                }
            }
            for observer in observers.values {
                observer(.batchCompleted(conversationID: conversationID, turnID: turnID, toolCalls: calls, results: results))
            }
            return results
        }
        func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
        func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
        func deleteToolCalls(for conversationID: UUID) async {}
    }

    /// 内存会话管理器：自动化级别可控。
    @MainActor
    private final class TestConversationManager: ConversationManaging {
        var conversations: [LumiConversationSummary] = []
        var selectedConversationID: UUID?
        var currentTitle: String = "No conversation"
        var globalVerbosity: LumiResponseVerbosity = .standard
        var globalReasoningEffort: LumiReasoningEffort?
        var globalAutomationLevel: LumiAutomationLevel = .build
        var globalLanguage: LumiConversationLanguage = .chinese
        private var automation: [UUID: LumiAutomationLevel] = [:]
        private var providerIDs: [UUID: String] = [:]
        private var modelNames: [UUID: String] = [:]

        @Published var tick = false

        func setAutomation(_ level: LumiAutomationLevel, for id: UUID) { automation[id] = level }
        func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
            guard let conversationID else { return globalAutomationLevel }
            return automation[conversationID] ?? globalAutomationLevel
        }
        func providerID(for conversationID: UUID?) -> String? {
            guard let conversationID else { return nil }
            return providerIDs[conversationID]
        }
        func modelName(for conversationID: UUID?) -> String? {
            guard let conversationID else { return nil }
            return modelNames[conversationID]
        }
        // 未用到的协议要求返回默认值。
        var dataDirectory: URL { URL(fileURLWithPath: "/tmp") }
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
        func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
        func setGlobalLanguage(_ language: LumiConversationLanguage) { globalLanguage = language }
        func language(for conversationID: UUID?) -> LumiConversationLanguage { globalLanguage }
        func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    }

    /// 组装测试用的 AgentLoop（构造注入）。
    private func makeLoop(
        messages: any MessageManaging,
        provider: any SuperLLMProvider,
        toolManager: any ToolManagerProviding = TestToolManager(),
        conversations: any ConversationManaging = TestConversationManager()
    ) -> DefaultAgentLoopProvider {
        let llmManager = ScriptedLLMManager(provider: provider)
        let streaming = DefaultMessageStreamingProviding()
        return DefaultAgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )
    }

    // MARK: - Tests

    @Test("流式 Provider 优先走 streamComplete 并写入流式 store")
    func usesStreamingPath() async throws {
        final class StreamingProvider: SuperLLMProvider, LLMStreamingProviding, @unchecked Sendable {
            nonisolated let providerID = "streaming"
            nonisolated let providerInfo = LLMProviderInfo(id: "streaming", displayName: "Streaming", defaultModel: "", models: [], isLocal: true)
            var streamed = false
            func complete(_ request: LLMRequest) async throws -> LLMResponse { LLMResponse(content: "non-stream") }
            func streamComplete(
                _ request: LLMRequest,
                onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
            ) async throws -> LLMResponse {
                streamed = true
                await onChunk(LLMStreamChunk(content: "你"))
                await onChunk(LLMStreamChunk(content: "好"))
                return LLMResponse(content: "你好", model: "test")
            }
        }

        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let provider = StreamingProvider()
        let loop = makeLoop(messages: messages, provider: provider)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(provider.streamed)
        #expect(messages.lastMessage(in: conversationID)?.content == "你好")
        // 临时行已清理
        #expect(DefaultMessageStreamingProviding().streamingMessage(for: conversationID) == nil)
    }

    @Test("工具调用循环：assistant 带工具 → 执行 → 结果回传 → 最终回复")
    func toolCallLoop() async throws {
        let tool = ScriptedTool(name: "fetch_weather", risk: .safe, result: ToolCallResult(content: "sunny"))
        let toolManager = TestToolManager()
        toolManager.add(tool, pluginID: "test")

        let provider = ScriptedLLMProvider(responses: [
            // 第一轮：请求执行工具
            LLMResponse(
                content: "",
                toolCalls: [LLMToolCall(id: "call-1", name: "fetch_weather", arguments: "{}")]
            ),
            // 第二轮：拿到工具结果后的最终回复
            LLMResponse(content: "今天晴天"),
        ])

        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "天气如何？"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.build, for: conversationID)

        let loop = makeLoop(messages: messages, provider: provider, toolManager: toolManager, conversations: conversations)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "今天晴天")
        // 直接验证工具执行结果（排除 mock 层差异）
        #expect(tool.executionCount == 1)
        #expect(toolManager.tool(named: "fetch_weather") != nil)
        // 工具结果消息已落库
        #expect(messages.messages(for: conversationID).contains { $0.role == MessageRole.tool && $0.content == "sunny" })
        // LLM 第二次请求的历史包含工具结果
        #expect(provider.receivedRequests.count == 2)
        #expect(provider.receivedRequests[1].messages.contains { $0.role == MessageRole.tool })
    }

    @Test("build 模式高风险工具挂起等待用户响应，响应后执行并完成")
    func highRiskSuspensionAndResume() async throws {
        let tool = ScriptedTool(name: "delete_file", risk: .high, result: ToolCallResult(content: "deleted"))
        let toolManager = TestToolManager()
        toolManager.add(tool, pluginID: "test")

        let provider = ScriptedLLMProvider(responses: [
            LLMResponse(content: "", toolCalls: [LLMToolCall(id: "call-1", name: "delete_file", arguments: "{}")]),
            LLMResponse(content: "已删除"),
        ])

        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "删掉它"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.build, for: conversationID)

        let loop = makeLoop(messages: messages, provider: provider, toolManager: toolManager, conversations: conversations)

        // 第一轮：高风险工具 → 挂起
        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .suspended("userInput:call-1"))
        #expect(loop.suspension(for: conversationID) != nil)
        #expect(loop.suspension(for: conversationID)?.kind == "userInput")
        #expect(tool.executionCount == 0, "高风险工具未批准不应执行")

        // 批准 → 恢复 → 工具执行 → 最终回复
        guard let suspension = loop.suspension(for: conversationID) else {
            Issue.record("缺少挂起点")
            return
        }
        let resumed = try await loop.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "允许")
        )
        #expect(resumed == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "已删除")
        #expect(tool.executionCount == 1)
    }

    @Test("chat 模式拒绝执行工具")
    func chatModeBlocksTools() async throws {
        let tool = ScriptedTool(name: "run_shell", risk: .safe, result: ToolCallResult(content: "executed"))
        let toolManager = TestToolManager()
        toolManager.add(tool, pluginID: "test")

        let provider = ScriptedLLMProvider(responses: [
            LLMResponse(content: "", toolCalls: [LLMToolCall(id: "call-1", name: "run_shell", arguments: "{}")]),
            LLMResponse(content: "完成"),
        ])

        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "执行"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.chat, for: conversationID)

        let loop = makeLoop(messages: messages, provider: provider, toolManager: toolManager, conversations: conversations)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(tool.executionCount == 0, "chat 模式不应执行任何工具")
        // 工具被拒绝的说明应回传给 LLM（.tool 消息带拒绝文案）
        #expect(messages.messages(for: conversationID).contains {
            $0.role == MessageRole.tool && $0.content.contains("blocked")
        })
    }
}
