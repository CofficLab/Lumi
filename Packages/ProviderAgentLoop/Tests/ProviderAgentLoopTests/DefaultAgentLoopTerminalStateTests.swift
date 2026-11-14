import Foundation
import Testing
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
@testable import ProviderAgentLoop

/// 锁定 DefaultAgentLoopProvider 的终态生命周期钩子（#219）与结构化失败详情（#230）。
///
/// 此前该实现只触发 `turnStarted`，completed / failed / cancelled / suspended
/// 四条终态路径都不触发 `turnFinished`，依赖终态钩子的插件（完成通知、
/// Goal 自动续跑、ConversationResume 终态标记）在回退装配下全部失效；
/// 失败时也不记录 `lastFailure`，常驻的自动重试插件拿不到可重试性判定，
/// 每次失败都直接清状态，自动重试永不触发；终态还会清空 `currentTurnID`，
/// 失败消息上的手动重试按钮永远隐藏（#231）。
///
/// 生产装配由 PluginAgentLoop 替换成 AgentLoopManager，但本实现仍是
/// 工厂默认产出与公开 API，终态钩子必须与 turnStarted 对称，且同一回合
/// 的终态恰好投递一次（cancelTurn 与迟到的 finishEventTurn 不得重复触发）。
@Suite("DefaultAgentLoop 终态钩子与失败详情（#219, #230, #231, #233）")
@MainActor
struct DefaultAgentLoopTerminalStateTests {

    private typealias ToolCall = KitAgentTool.ToolCall

    // MARK: - Test Doubles

    @MainActor
    private final class ScriptedLLMProvider: SuperLLMProvider {
        nonisolated let providerID = "scripted"
        nonisolated let providerInfo = LLMProviderInfo(id: "scripted", displayName: "Scripted", defaultModel: "", models: [], isLocal: true)
        var responses: [LLMResponse]
        var error: Error?

        init(responses: [LLMResponse] = [], error: Error? = nil) {
            self.responses = responses
            self.error = error
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            if let error { throw error }
            guard !responses.isEmpty else { return LLMResponse(content: "") }
            return responses.removeFirst()
        }
    }

    /// 请求被门闩挂起的 Provider：构造「取消后旧响应才迟到」的场景。
    @MainActor
    private final class GatedLLMProvider: SuperLLMProvider {
        nonisolated let providerID = "gated"
        nonisolated let providerInfo = LLMProviderInfo(id: "gated", displayName: "Gated", defaultModel: "", models: [], isLocal: true)
        private(set) var requestStarted = false
        private(set) var requestFinished = false
        var response = LLMResponse(content: "late response")
        private var gate: CheckedContinuation<Void, Never>?

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            requestStarted = true
            await withCheckedContinuation { gate = $0 }
            requestFinished = true
            return response
        }

        func release() {
            gate?.resume()
            gate = nil
        }
    }

    @MainActor
    private final class ScriptedLLMManager: LLMManaging, @unchecked Sendable {
        var provider: any SuperLLMProvider
        init(provider: any SuperLLMProvider) { self.provider = provider }

        var providerID: String { "scripted-manager" }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: "scripted-manager", displayName: "Scripted Manager", defaultModel: "", models: [], isLocal: true)
        }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            try await provider.complete(request)
        }
        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { provider }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { "scripted-manager" }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    }

    private final class ScriptedTool: SuperAgentTool, @unchecked Sendable {
        let name: String
        let risk: CommandRiskLevel
        private(set) var executionCount = 0
        init(name: String, risk: CommandRiskLevel) {
            self.name = name
            self.risk = risk
        }
        func description(for language: LanguagePreference) -> String { "Tool \(name)" }
        func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { risk }
        func displayDescription(for arguments: [String: ToolArgument]) -> String { "执行 \(name)" }
        func execute(arguments: [String: ToolArgument]) async throws -> String {
            executionCount += 1
            return "ok"
        }
    }

    @MainActor
    private final class TestToolManager: ToolManagerProviding {
        private var tools: [String: any SuperAgentTool] = [:]
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

        func add(_ tool: any SuperAgentTool, pluginID: String) { tools[tool.name] = tool }
        func allTools() -> [any SuperAgentTool] { Array(tools.values) }
        func remove(id: String) { tools.removeValue(forKey: id) }
        func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [("test", allTools())] }
        func tool(named name: String) -> (any SuperAgentTool)? { tools[name] }
        func displayDescription(for toolCall: ToolCall) -> String? { nil }
        func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? {
            tools[toolCall.name]?.permissionRiskLevel(arguments: [:])
        }
        func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
            ToolCallResult(content: "ok")
        }
        func executeBatch(_ calls: [ToolCall], policy: ToolExecutionPolicy, conversationID: UUID, turnID: UUID?) async -> [BatchToolResult] {
            var results: [BatchToolResult] = []
            for call in calls {
                let risk = riskLevel(for: call) ?? .high
                if policy == .requireApprovalForHighRisk && risk.requiresPermission {
                    let payload = "{\"toolCallId\":\"approval:\(call.id)\",\"kind\":\"permission\",\"question\":\"需要确认\",\"options\":[\"允许\",\"拒绝\"],\"mode\":\"yes_no\"}"
                    results.append(.needsUserResponse(payload: payload))
                } else {
                    results.append(.executed(await execute(call, conversationID: conversationID, turnID: turnID)))
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

    @MainActor
    private final class TestConversationManager: ConversationManaging {
        var conversations: [ConversationSummary] = []
        var currentTitle: String = "No conversation"
        var selectedConversationID: UUID?
        var globalAutomationLevel: AutomationLevel = .build
        var globalVerbosity: ResponseVerbosity = .standard
        var globalReasoningEffort: ReasoningEffort?
        var globalLanguage: ConversationLanguage = .chinese
        private var automation: [UUID: AutomationLevel] = [:]

        func setAutomation(_ level: AutomationLevel, for id: UUID) { automation[id] = level }
        func automationLevel(for conversationID: UUID?) -> AutomationLevel {
            guard let conversationID else { return globalAutomationLevel }
            return automation[conversationID] ?? globalAutomationLevel
        }
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
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
        func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {}
        func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .standard }
        func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {}
        func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .defaultEffort }
        func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { nil }
        func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {}
        func clearReasoningEffort(for conversationID: UUID?) {}
        func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) { globalAutomationLevel = automationLevel }
        func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {}
        func setGlobalLanguage(_ language: ConversationLanguage) {}
        func language(for conversationID: UUID?) -> ConversationLanguage { .chinese }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    }

    // MARK: - Harness

    private func makeHarness(
        provider: any SuperLLMProvider,
        toolManager: TestToolManager = TestToolManager()
    ) -> (loop: DefaultAgentLoopProvider, manager: ScriptedLLMManager, messages: DefaultMessageManager, hooks: DefaultLifecycleHooksProvider, conversationID: UUID) {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let manager = ScriptedLLMManager(provider: provider)
        let loop = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: manager,
            toolManager: toolManager,
            streaming: DefaultMessageStreamingProviding(),
            conversations: TestConversationManager()
        )
        let hooks = DefaultLifecycleHooksProvider()
        loop.setLifecycleHooks(hooks)
        return (loop, manager, messages, hooks, conversationID)
    }

    /// 钩子广播走异步 Task，轮询等待期望的投递数量。
    private func waitUntil(timeout: TimeInterval = 5, condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    // MARK: - Tests

    @Test("完成回合触发 turnFinished，turnID 与 turnStarted 对称")
    func completedTurnFiresFinishedHook() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(responses: [LLMResponse(content: "done")]))
        var started: [TurnLifecycleContext] = []
        var finished: [TurnLifecycleContext] = []
        harness.hooks.addTurnStartedHook { started.append($0) }
        harness.hooks.addTurnFinishedHook { finished.append($0) }

        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        #expect(outcome == .completed)
        #expect(await waitUntil { finished.count == 1 })
        #expect(started.count == 1)
        #expect(finished.first?.endReason == .completed)
        #expect(finished.first?.conversationID == harness.conversationID)
        #expect(finished.first?.turnID == started.first?.turnID)
    }

    @Test("失败回合触发 turnFinished(.failed)")
    func failedTurnFiresFinishedHook() async throws {
        struct ProbeError: Error {}
        let harness = makeHarness(provider: ScriptedLLMProvider(error: ProbeError()))
        var finished: [TurnLifecycleContext] = []
        harness.hooks.addTurnFinishedHook { finished.append($0) }

        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        guard case .failed = outcome else {
            Issue.record("期望失败结局，实际 \(outcome)")
            return
        }
        #expect(await waitUntil { finished.count == 1 })
        #expect(finished.first?.endReason == .failed)
    }

    @Test("取消回合恰好触发一次 turnFinished(.cancelled)，迟到的完成不再重复投递")
    func cancelledTurnFiresFinishedHookExactlyOnce() async throws {
        let provider = GatedLLMProvider()
        let harness = makeHarness(provider: provider)
        var finished: [TurnLifecycleContext] = []
        harness.hooks.addTurnFinishedHook { finished.append($0) }

        let turnTask = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { provider.requestStarted }, "LLM 请求未发起")

        harness.loop.cancelTurn(in: harness.conversationID)
        let outcome = try await turnTask.value
        #expect(outcome == .cancelled)

        // 放行迟到的旧响应：它会走完 finishEventTurn(.completed)，
        // 但同一回合的终态钩子不得第二次投递。
        provider.release()
        #expect(await waitUntil { provider.requestFinished }, "迟到的请求未收尾")
        #expect(await waitUntil { finished.count >= 1 })
        // 再留一段投递窗口，确认没有第二次。
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(finished.count == 1, "终态钩子重复投递：\(finished.map { String(describing: $0.endReason) })")
        #expect(finished.first?.endReason == .cancelled)
    }

    @Test("挂起触发 turnFinished(.suspended)，恢复完成后同 turnID 再投递 .completed")
    func suspensionThenResumeFiresBothHooks() async throws {
        let toolManager = TestToolManager()
        toolManager.add(ScriptedTool(name: "delete_file", risk: .high), pluginID: "test")
        let harness = makeHarness(
            provider: ScriptedLLMProvider(responses: [
                LLMResponse(content: "", toolCalls: [LLMToolCall(id: "call-1", name: "delete_file", arguments: "{}")]),
                LLMResponse(content: "已删除"),
            ]),
            toolManager: toolManager
        )
        var started: [TurnLifecycleContext] = []
        var finished: [TurnLifecycleContext] = []
        harness.hooks.addTurnStartedHook { started.append($0) }
        harness.hooks.addTurnFinishedHook { finished.append($0) }

        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        #expect(outcome == .suspended("userInput:call-1"))
        #expect(await waitUntil { finished.count == 1 })
        #expect(finished.first?.endReason == .suspended)

        guard let suspension = harness.loop.suspension(for: harness.conversationID) else {
            Issue.record("缺少挂起点")
            return
        }
        let resumed = try await harness.loop.resumeTurn(
            in: harness.conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "允许")
        )
        #expect(resumed == .completed)
        #expect(await waitUntil { finished.count == 2 })
        #expect(finished.map(\.endReason) == [.suspended, .completed])
        #expect(started.count == 1, "恢复不是新回合，不应再次 turnStarted")
        #expect(Set(finished.map(\.turnID)).count == 1, "挂起与完成必须沿用同一 turnID")
        #expect(finished.first?.turnID == started.first?.turnID)
    }

    @Test("没有活跃回合时取消不触发 turnFinished")
    func cancelWithoutActiveTurnDoesNotFire() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(responses: [LLMResponse(content: "done")]))
        var finished: [TurnLifecycleContext] = []
        harness.hooks.addTurnFinishedHook { finished.append($0) }

        harness.loop.cancelTurn(in: harness.conversationID)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(finished.isEmpty)
    }

    // MARK: - 结构化失败详情（#230）

    @Test("限流失败暴露结构化 lastFailure，含 Retry-After 供自动重试消费")
    func rateLimitedFailureExposesStructuredDetails() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(
            error: VendorAPIError.httpStatus(statusCode: 429, summary: "rate limited", retryAfterSeconds: 7)
        ))

        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        guard case .failed = outcome else {
            Issue.record("期望失败结局，实际 \(outcome)")
            return
        }
        let failure = harness.loop.lastFailure(for: harness.conversationID)
        #expect(failure?.kind == .rateLimited)
        #expect(failure?.isRetryable == true)
        #expect(failure?.httpStatusCode == 429)
        #expect(failure?.retryAfterSeconds == 7)
    }

    @Test("鉴权失败同样落 lastFailure，但标记为不可自动重试")
    func authenticationFailureIsStoredButNotRetryable() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(
            error: VendorAPIError.missingAPIKey("scripted")
        ))

        _ = try await harness.loop.runTurn(in: harness.conversationID)
        let failure = harness.loop.lastFailure(for: harness.conversationID)
        #expect(failure?.kind == .authentication)
        #expect(failure?.isRetryable == false)
    }

    @Test("空终态响应归类为可重试的 emptyResponse 失败")
    func emptyResponseIsRetryableFailure() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(responses: [LLMResponse(content: "")]))

        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        guard case .failed = outcome else {
            Issue.record("期望失败结局，实际 \(outcome)")
            return
        }
        let failure = harness.loop.lastFailure(for: harness.conversationID)
        #expect(failure?.kind == .emptyResponse)
        #expect(failure?.isRetryable == true)
    }

    @Test("新回合开始时清除上一回合的失败详情")
    func newTurnClearsPreviousFailure() async throws {
        let provider = ScriptedLLMProvider(error: VendorAPIError.httpStatus(statusCode: 500, summary: "boom", retryAfterSeconds: nil))
        let harness = makeHarness(provider: provider)

        _ = try await harness.loop.runTurn(in: harness.conversationID)
        #expect(harness.loop.lastFailure(for: harness.conversationID) != nil)

        provider.error = nil
        provider.responses = [LLMResponse(content: "ok")]
        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        #expect(outcome == .completed)
        #expect(harness.loop.lastFailure(for: harness.conversationID) == nil)
    }

    // MARK: - 失败回合身份与手动重试（#231）

    @Test("失败终态保留 currentTurnID，重试按钮可定位失败回合")
    func failedTurnRetainsCurrentTurnID() async throws {
        struct ProbeError: Error {}
        let harness = makeHarness(provider: ScriptedLLMProvider(error: ProbeError()))
        var failedTurnID: UUID?
        let observer = harness.loop.addAgentLoopObserver { event in
            if case let .failed(_, turnID, _) = event { failedTurnID = turnID }
        }

        _ = try await harness.loop.runTurn(in: harness.conversationID)
        observer.cancel()
        #expect(harness.loop.state(for: harness.conversationID) == .failed)
        #expect(failedTurnID != nil)
        #expect(harness.loop.currentTurnID(for: harness.conversationID) == failedTurnID)
    }

    @Test("retryTurn 校验失败回合身份后重启并完成")
    func retryTurnRestartsMatchingFailedTurn() async throws {
        let provider = ScriptedLLMProvider(error: VendorAPIError.httpStatus(statusCode: 500, summary: "boom", retryAfterSeconds: nil))
        let harness = makeHarness(provider: provider)

        _ = try await harness.loop.runTurn(in: harness.conversationID)
        guard let failedTurnID = harness.loop.currentTurnID(for: harness.conversationID) else {
            Issue.record("失败回合缺少 turnID")
            return
        }

        provider.error = nil
        provider.responses = [LLMResponse(content: "retried")]
        let outcome = try await harness.loop.retryTurn(in: harness.conversationID, after: failedTurnID)
        #expect(outcome == .completed)
        #expect(harness.loop.lastFailure(for: harness.conversationID) == nil)
    }

    @Test("retryTurn 拒绝过期的失败回合身份")
    func retryTurnRejectsStaleTurnID() async throws {
        let provider = ScriptedLLMProvider(error: VendorAPIError.httpStatus(statusCode: 500, summary: "boom", retryAfterSeconds: nil))
        let harness = makeHarness(provider: provider)

        _ = try await harness.loop.runTurn(in: harness.conversationID)
        guard let failedTurnID = harness.loop.currentTurnID(for: harness.conversationID) else {
            Issue.record("失败回合缺少 turnID")
            return
        }

        // 随便一个旧 turnID 不得重启当前失败回合。
        await #expect(throws: AgentLoopError.invalidRetryRequest) {
            _ = try await harness.loop.retryTurn(in: harness.conversationID, after: UUID())
        }

        // 新回合成功后，旧失败回合的重试请求同样必须被拒绝。
        provider.error = nil
        provider.responses = [LLMResponse(content: "ok")]
        _ = try await harness.loop.runTurn(in: harness.conversationID)
        await #expect(throws: AgentLoopError.invalidRetryRequest) {
            _ = try await harness.loop.retryTurn(in: harness.conversationID, after: failedTurnID)
        }
    }

    @Test("非失败状态不允许 retryTurn")
    func retryTurnRequiresFailedState() async throws {
        let harness = makeHarness(provider: ScriptedLLMProvider(responses: [LLMResponse(content: "done")]))
        _ = try await harness.loop.runTurn(in: harness.conversationID)
        guard let turnID = harness.loop.currentTurnID(for: harness.conversationID) else {
            Issue.record("完成回合缺少 turnID")
            return
        }
        await #expect(throws: AgentLoopError.invalidRetryRequest) {
            _ = try await harness.loop.retryTurn(in: harness.conversationID, after: turnID)
        }
    }

    // MARK: - 取消后迟到的响应（#233）

    @Test("取消后迟到的普通响应不落库，状态保持 cancelled")
    func lateResponseAfterCancelIsNotPersisted() async throws {
        let provider = GatedLLMProvider()
        let harness = makeHarness(provider: provider)

        let turnTask = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { provider.requestStarted }, "LLM 请求未发起")
        harness.loop.cancelTurn(in: harness.conversationID)
        #expect(try await turnTask.value == .cancelled)

        provider.release()
        #expect(await waitUntil { provider.requestFinished }, "迟到的请求未收尾")
        try await Task.sleep(nanoseconds: 100_000_000)

        let history = await harness.messages.messagesSnapshot(in: harness.conversationID)
        #expect(!history.contains { $0.role == .assistant }, "迟到响应不得写入会话")
        #expect(harness.loop.state(for: harness.conversationID) == .cancelled)
    }

    @Test("取消后迟到的工具调用不得执行")
    func lateToolCallsAfterCancelDoNotExecute() async throws {
        let tool = ScriptedTool(name: "fetch_weather", risk: .safe)
        let toolManager = TestToolManager()
        toolManager.add(tool, pluginID: "test")
        let provider = GatedLLMProvider()
        provider.response = LLMResponse(
            content: "",
            toolCalls: [LLMToolCall(id: "call-1", name: "fetch_weather", arguments: "{}")]
        )
        let harness = makeHarness(provider: provider, toolManager: toolManager)

        let turnTask = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { provider.requestStarted }, "LLM 请求未发起")
        harness.loop.cancelTurn(in: harness.conversationID)
        #expect(try await turnTask.value == .cancelled)

        provider.release()
        #expect(await waitUntil { provider.requestFinished }, "迟到的请求未收尾")
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(tool.executionCount == 0, "取消后不得执行工具")
        let history = await harness.messages.messagesSnapshot(in: harness.conversationID)
        #expect(!history.contains { $0.role == .assistant || $0.role == .tool }, "迟到响应与工具结果不得落库")
        #expect(harness.loop.state(for: harness.conversationID) == .cancelled)
    }

    @Test("取消后同一会话的新回合不受旧请求迟到响应影响")
    func newTurnAfterCancelStillWorks() async throws {
        let provider = GatedLLMProvider()
        let harness = makeHarness(provider: provider)

        let turnTask = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { provider.requestStarted })
        harness.loop.cancelTurn(in: harness.conversationID)
        _ = try await turnTask.value

        // 旧请求还挂在门闩上时就开始新回合；旧响应随后迟到，
        // 必须按 turnID 丢弃，不得污染新回合的历史。
        harness.manager.provider = ScriptedLLMProvider(responses: [LLMResponse(content: "fresh")])
        let outcome = try await harness.loop.runTurn(in: harness.conversationID)
        #expect(outcome == .completed)

        provider.release()
        #expect(await waitUntil { provider.requestFinished })
        try await Task.sleep(nanoseconds: 100_000_000)

        let history = await harness.messages.messagesSnapshot(in: harness.conversationID)
        #expect(history.filter { $0.role == .assistant }.map(\.content) == ["fresh"])
        #expect(harness.loop.state(for: harness.conversationID) == .completed)
    }

    @Test("旧回合在新回合运行中迟到返回，不得覆盖新回合状态（#438）")
    func lateOldTurnReturnDoesNotOverwriteNewTurn() async throws {
        let oldProvider = GatedLLMProvider()
        let harness = makeHarness(provider: oldProvider)
        var startedTurns: [UUID] = []
        let observer = harness.loop.addAgentLoopObserver { event in
            if case let .started(_, turn) = event { startedTurns.append(turn) }
        }
        defer { observer.cancel() }

        let turnTaskA = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { oldProvider.requestStarted })
        harness.loop.cancelTurn(in: harness.conversationID)
        _ = try await turnTaskA.value

        let newProvider = GatedLLMProvider()
        newProvider.response = LLMResponse(content: "fresh")
        harness.manager.provider = newProvider
        let turnTaskB = Task { try await harness.loop.runTurn(in: harness.conversationID) }
        #expect(await waitUntil { newProvider.requestStarted })

        // A 在 B 运行中迟到返回：不得清掉 B 的句柄、不得发布 A 的终态。
        oldProvider.release()
        #expect(await waitUntil { oldProvider.requestFinished })
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(harness.loop.state(for: harness.conversationID) == .running)
        #expect(harness.loop.isRunning(for: harness.conversationID))
        #expect(startedTurns.count == 2)
        #expect(harness.loop.currentTurnID(for: harness.conversationID) == startedTurns.last)

        newProvider.release()
        #expect(try await turnTaskB.value == .completed)
        let history = await harness.messages.messagesSnapshot(in: harness.conversationID)
        #expect(history.filter { $0.role == .assistant }.map(\.content) == ["fresh"])
    }
}