import Foundation
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderToolManager
import Testing
@testable import PluginSubagent

/// ChatToolbar 子代理运行指示器的 ViewModel 契约。
///
/// - 只有 `run_subagent` 的 Job 计入徽标，且只属于当前选中会话；
/// - 旧会话的晚到事件不得污染新会话状态（仓库异步写回身份校验约定）；
/// - 运行中的任务驱动计时刷新，全部终态后停止（ToolActivity #960 同款回归）。
@MainActor
@Suite("Subagent Activity ViewModel")
struct SubagentActivityViewModelTests {

    @Test("run_subagent 计入徽标，其他工具不计入")
    func onlySubagentJobsCountTowardBadge() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        toolManager.emit(.started(makeJob(id: "sub-1", conversationID: conversationID, status: .running)))
        toolManager.emit(.started(
            makeJob(id: "sub-2", conversationID: conversationID, status: .queued)
        ))
        toolManager.emit(.started(makeJob(
            id: "other",
            conversationID: conversationID,
            status: .running,
            toolName: "read_file"
        )))

        #expect(viewModel.activeCount == 2, "并行的两个子代理都应计入，其他工具不算")
        #expect(viewModel.activeSubagents.map(\.id) == ["sub-1", "sub-2"])
        viewModel.cancel()
    }

    @Test("Job 进入终态后退出运行中并进入已结束列表")
    func terminalJobsLeaveActiveAndEnterFinished() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        let jobStart = Date()
        let started = makeJob(
            id: "sub-1",
            conversationID: conversationID,
            status: .running,
            startedAt: jobStart
        )
        toolManager.emit(.started(started))
        #expect(viewModel.activeCount == 1)

        var finished = started
        finished.status = .completed
        finished.completedAt = jobStart.addingTimeInterval(3)
        toolManager.emit(.completed(
            jobID: finished.id,
            result: ToolCallResult(content: "conclusion"),
            snapshot: finished
        ))

        #expect(viewModel.activeCount == 0, "终态后徽标归零")
        #expect(viewModel.finishedSubagents.map(\.id) == [finished.id])
        #expect(!viewModel.isFailed(finished))
        viewModel.cancel()
    }

    @Test("执行抛异常与结构化错误结果都视为失败")
    func failureShapesAreRecognized() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        var thrown = makeJob(id: "sub-throw", conversationID: conversationID, status: .running)
        thrown.status = .failed
        toolManager.emit(.failed(
            jobID: thrown.id,
            result: ToolCallResult(content: ""),
            snapshot: thrown
        ))

        let errored = makeJob(
            id: "sub-error",
            conversationID: conversationID,
            status: .completed,
            result: ToolCallResult(content: "failed", isError: true)
        )
        toolManager.emit(.completed(
            jobID: errored.id,
            result: ToolCallResult(content: "failed", isError: true),
            snapshot: errored
        ))

        #expect(viewModel.isFailed(thrown))
        #expect(viewModel.isFailed(errored))
        viewModel.cancel()
    }

    /// 身份校验：其他会话的 run_subagent 事件不得写入当前会话状态。
    @Test("其他会话的子代理事件被忽略")
    func eventsFromOtherConversationsAreIgnored() {
        let conversationID = UUID()
        let otherConversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        toolManager.emit(.started(makeJob(id: "foreign", conversationID: otherConversationID, status: .running)))

        #expect(viewModel.jobs.isEmpty, "非当前会话的委托不得出现在指示器里")
        viewModel.cancel()
    }

    /// 旧会话的 Job 在选中会话切换后晚到，不得覆盖新会话状态。
    @Test("切换会话后旧会话晚到事件被丢弃，列表重读为新会话")
    func staleEventsAfterConversationSwitchAreDropped() {
        let oldConversationID = UUID()
        let newConversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = oldConversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        let stale = makeJob(id: "stale", conversationID: oldConversationID, status: .running)
        toolManager.emit(.started(stale))
        #expect(viewModel.activeCount == 1)

        conversations.selectConversation(id: newConversationID)
        #expect(viewModel.jobs.isEmpty, "切换后应重读新会话的列表")

        toolManager.emit(.progress(
            jobID: stale.id,
            progress: ToolJobProgress(message: "late"),
            snapshot: stale
        ))
        #expect(viewModel.jobs.isEmpty, "旧会话晚到事件不得写回新会话状态")
        viewModel.cancel()
    }

    @Test("恢复批量快照补进列表")
    func restoredEventRefreshesSnapshot() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        let restored = makeJob(id: "restored", conversationID: conversationID, status: .completed)
        toolManager.jobsByConversation[conversationID] = [restored]
        toolManager.emit(.restored([restored]))

        #expect(viewModel.finishedSubagents.map(\.id) == [restored.id])
        viewModel.cancel()
    }

    @Test("标签取 description 参数，缺失或空白回退默认文案")
    func labelFallsBackWhenDescriptionMissing() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = makeViewModel(conversations: conversations, toolManager: toolManager)

        let labeled = makeJob(
            id: "labeled",
            conversationID: conversationID,
            status: .running,
            arguments: #"{"task":"do things","description":"Explore the codebase"}"#
        )
        let blank = makeJob(
            id: "blank",
            conversationID: conversationID,
            status: .running,
            arguments: #"{"description":"   "}"#
        )
        let missing = makeJob(id: "missing", conversationID: conversationID, status: .running)

        #expect(viewModel.label(for: labeled) == "Explore the codebase")
        #expect(viewModel.label(for: blank) == pluginLocalization.string("Subagent task"))
        #expect(viewModel.label(for: missing) == pluginLocalization.string("Subagent task"))
        viewModel.cancel()
    }

    /// ToolActivity #960 同款回归：静默运行期只有计时器推进时间，耗时也要增长。
    @Test("运行中驱动计时刷新，全部终态后停止；静默期耗时随时间增长")
    func tickingFollowsActiveJobsAndSilentDurationAdvances() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let startedAt = Date()
        var clock = startedAt
        let viewModel = makeViewModel(
            conversations: conversations,
            toolManager: toolManager,
            dateProvider: { clock }
        )
        #expect(!viewModel.isTicking, "没有任务时不应空转计时器")

        let running = makeJob(
            id: "sub-1",
            conversationID: conversationID,
            status: .running,
            startedAt: startedAt
        )
        toolManager.emit(.started(running))
        #expect(viewModel.isTicking, "运行中的子代理必须驱动耗时刷新")

        clock = startedAt.addingTimeInterval(5)
        viewModel.tick()
        #expect(viewModel.elapsedDuration(for: running) == 5, "静默期耗时没有随当前时间增长")
        #expect(viewModel.formatDuration(5) == "5.0s")

        var finished = running
        finished.status = .completed
        finished.completedAt = startedAt.addingTimeInterval(12)
        toolManager.emit(.completed(
            jobID: finished.id,
            result: ToolCallResult(content: "done"),
            snapshot: finished
        ))
        #expect(!viewModel.isTicking, "全部终态后应停止计时，避免无意义的重绘")

        clock = startedAt.addingTimeInterval(90)
        viewModel.tick()
        #expect(viewModel.elapsedDuration(for: finished) == 12, "终态后耗时固定为最终值")
        viewModel.cancel()
    }

    // MARK: - Helpers

    private func makeViewModel(
        conversations: StubConversationManager,
        toolManager: StubToolManager,
        dateProvider: @escaping () -> Date = Date.init
    ) -> SubagentActivityViewModel {
        let viewModel = SubagentActivityViewModel(
            conversations: conversations,
            toolManager: toolManager,
            dateProvider: dateProvider
        )
        return viewModel
    }

    private func makeJob(
        id: String,
        conversationID: UUID,
        status: ToolJobStatus,
        toolName: String = RunSubagentTool.toolName,
        arguments: String = "{}",
        result: ToolCallResult? = nil,
        startedAt: Date? = nil
    ) -> ToolJob {
        ToolJob(
            id: id,
            conversationID: conversationID,
            turnID: UUID(),
            toolCall: KitAgentTool.ToolCall(
                id: "call-\(id)",
                name: toolName,
                arguments: arguments,
                result: result
            ),
            status: status,
            startedAt: startedAt
        )
    }
}

@MainActor
private final class StubToolManager: ToolManagerProviding {
    var jobsByConversation: [UUID: [ToolJob]] = [:]
    private var jobObservers: [(ToolJobEvent) -> Void] = []

    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        jobObservers.append(callback)
        return StubToolJobObserverHandle()
    }

    func emit(_ event: ToolJobEvent) {
        for observer in jobObservers {
            observer(event)
        }
    }

    func jobs(forConversationID conversationID: UUID) -> [ToolJob] {
        jobsByConversation[conversationID] ?? []
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
    func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { nil }

    func execute(
        _ toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        ToolCallResult(content: "not implemented", isError: true)
    }

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor
private final class StubToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}

@MainActor
private final class StubConversationManager: ConversationManaging {
    var conversations: [ConversationSummary] = []
    var selectedConversationID: UUID?
    var currentTitle: String = ""
    var dataDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    private var selectionObservers: [(UUID?) -> Void] = []

    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        selectionObservers.append(callback)
        return NoopSelectedConversationObserverHandle()
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID { UUID() }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID { UUID() }

    func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?
    ) throws -> UUID { UUID() }

    func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID { UUID() }

    func selectConversation(id: UUID) {
        selectedConversationID = id
        for observer in selectionObservers { observer(id) }
    }

    func deselectConversation() {
        selectedConversationID = nil
        for observer in selectionObservers { observer(nil) }
    }
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }
    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }

    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    var globalVerbosity: ResponseVerbosity = .standard
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) { globalVerbosity = verbosity }
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { globalVerbosity }

    var globalReasoningEffort: ReasoningEffort?
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {
        globalReasoningEffort = reasoningEffort
    }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort {
        globalReasoningEffort ?? ReasoningEffort.defaultEffort
    }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? {
        globalReasoningEffort
    }
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}

    var globalAutomationLevel: AutomationLevel = .build
    func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {
        globalAutomationLevel = automationLevel
    }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { globalAutomationLevel }
    func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {}

    var globalLanguage: ConversationLanguage = .english
    func setGlobalLanguage(_ language: ConversationLanguage) { globalLanguage = language }
    func language(for conversationID: UUID?) -> ConversationLanguage { globalLanguage }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
}

@MainActor
private final class NoopSelectedConversationObserverHandle: SelectedConversationObserverHandle {
    func cancel() {}
}
