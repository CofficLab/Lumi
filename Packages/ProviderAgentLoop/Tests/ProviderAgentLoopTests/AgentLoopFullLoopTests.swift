import Combine
import Foundation
import Testing
import AgentToolKit
import ProviderMessage
import KitLLM
import ProviderConversation
import ProviderToolManager
import ProviderMessageStreaming
@testable import ProviderAgentLoop

@Suite("AgentLoop 完整回合循环")
@MainActor
struct AgentLoopFullLoopTests {

    // MARK: - Test Doubles

    /// 可编排响应序列的 LLM Provider：按调用次数依次返回预设响应。
    private final class ScriptedLLMProvider: LLMProviding, @unchecked Sendable {
        let providerID = "scripted"
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
        // 注意：executeResult 是 SuperAgentTool 协议扩展方法（非协议要求），
        // 对 `any SuperAgentTool` 调用时静态分派到扩展默认实现（内部调 execute），
        // 因此在 execute 中计数。
        func execute(arguments: [String: ToolArgument]) async throws -> String {
            executionCount += 1
            return result.content
        }
    }

    /// 内存 ToolManager（对齐协议）。
    private final class TestToolManager: ToolManagerProviding, @unchecked Sendable {
        private var tools: [String: any SuperAgentTool] = [:]
        private var order: [String] = []

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

    // MARK: - Tests

    @Test("流式 Provider 优先走 streamComplete 并写入流式 store")
    func usesStreamingPath() async throws {
        final class StreamingProvider: LLMProviding, LLMStreamingProviding, @unchecked Sendable {
            let providerID = "streaming"
            var streamed = false
            func complete(_ request: LLMRequest) async throws -> LLMResponse { LLMResponse(content: "non-stream") }
            func streamComplete(
                _ request: LLMRequest,
                onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
            ) async throws -> LLMResponse {
                streamed = true
                await onChunk(LLMStreamChunk(content: "你", isThinking: false))
                await onChunk(LLMStreamChunk(content: "好", isThinking: false))
                return LLMResponse(content: "你好", model: "test")
            }
        }

        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let streaming = DefaultMessageStreamingProviding()
        let provider = StreamingProvider()
        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: provider)
        loop.setStreaming(streaming)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(provider.streamed)
        #expect(messages.lastMessage(in: conversationID)?.content == "你好")
        // 临时行已清理
        #expect(streaming.streamingMessage(for: conversationID) == nil)
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
                toolCalls: [MessageToolCall(id: "call-1", name: "fetch_weather", arguments: "{}")]
            ),
            // 第二轮：拿到工具结果后的最终回复
            LLMResponse(content: "今天晴天"),
        ])

        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "天气如何？"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.build, for: conversationID)

        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: provider)
        loop.setToolManager(toolManager)
        loop.setConversations(conversations)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "今天晴天")
        // 直接验证工具执行结果（排除 mock 层差异）
        #expect(tool.executionCount == 1)
        #expect(toolManager.tool(named: "fetch_weather") != nil)
        // 工具结果消息已落库
        #expect(messages.messages(for: conversationID).contains { $0.role == .tool && $0.content == "sunny" })
        // LLM 第二次请求的历史包含工具结果
        #expect(provider.receivedRequests.count == 2)
        #expect(provider.receivedRequests[1].messages.contains { $0.role == .tool })
    }

    @Test("build 模式高风险工具挂起等待批准，批准后执行并完成")
    func highRiskSuspensionAndResume() async throws {
        let tool = ScriptedTool(name: "delete_file", risk: .high, result: ToolCallResult(content: "deleted"))
        let toolManager = TestToolManager()
        toolManager.add(tool, pluginID: "test")

        let provider = ScriptedLLMProvider(responses: [
            LLMResponse(content: "", toolCalls: [MessageToolCall(id: "call-1", name: "delete_file", arguments: "{}")]),
            LLMResponse(content: "已删除"),
        ])

        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "删掉它"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.build, for: conversationID)

        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: provider)
        loop.setToolManager(toolManager)
        loop.setConversations(conversations)

        // 第一轮：高风险工具 → 挂起
        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .suspended("awaiting user response"))
        #expect(loop.suspension(for: conversationID) != nil)
        #expect(loop.suspension(for: conversationID)?.kind == "toolApproval")
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
            LLMResponse(content: "", toolCalls: [MessageToolCall(id: "call-1", name: "run_shell", arguments: "{}")]),
            LLMResponse(content: "完成"),
        ])

        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "执行"), to: conversationID)
        let conversations = TestConversationManager()
        conversations.setAutomation(.chat, for: conversationID)

        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: provider)
        loop.setToolManager(toolManager)
        loop.setConversations(conversations)

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(tool.executionCount == 0, "chat 模式不应执行任何工具")
        // 工具被拒绝的说明应回传给 LLM（.tool 消息带拒绝文案）
        #expect(messages.messages(for: conversationID).contains {
            $0.role == .tool && $0.content.contains("blocked")
        })
    }

    @Test("回合生命周期事件经回调广播")
    func publishesEvents() async throws {
        var events: [AgentLoopEvent] = []
        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: ScriptedLLMProvider(responses: [LLMResponse(content: "ok")]))
        loop.setEventHandler { events.append($0) }

        _ = try await loop.runTurn(in: conversationID)

        let kinds = events.map { event -> String in
            switch event {
            case .turnStarted: return "started"
            case .messageSaved: return "saved"
            case .turnCompleted: return "completed"
            case .turnFinished: return "finished"
            }
        }
        #expect(kinds.contains("started"))
        #expect(kinds.contains("saved"))
        #expect(kinds.contains("completed"))
        #expect(kinds.contains("finished"))
    }
}
