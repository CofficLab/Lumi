import Foundation
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderToolManager
import Testing
@testable import PluginToolActivity

/// 回归 #544：面板打开期间异步恢复出来的历史任务必须能显示。
@Suite("Tool Activity ViewModel")
@MainActor
struct ToolActivityViewModelTests {
    @Test("恢复批量快照后，打开中的面板刷新出历史任务")
    func restoredEventRefreshesOpenPanel() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()

        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)
        #expect(viewModel.jobs.isEmpty, "打开时还没有恢复任何任务")

        let job = ToolJob(
            id: "restored-job",
            conversationID: conversationID,
            turnID: UUID(),
            toolCall: KitAgentTool.ToolCall(id: "call-restored", name: "run_command", arguments: "{}"),
            status: .completed,
            completedAt: Date()
        )
        toolManager.jobsByConversation[conversationID] = [job]
        toolManager.emit(.restored([job]))

        #expect(viewModel.completedJobs.map(\.id) == [job.id])
        #expect(viewModel.activeCount == 0)
    }

    @Test("completed 但 isError=true 的结果显示为失败")
    func completedErrorResultShowsFailedStatus() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)

        let job = ToolJob(
            id: "job-error",
            conversationID: conversationID,
            toolCall: KitAgentTool.ToolCall(id: "call-error", name: "read_image", arguments: "{}"),
            status: .completed,
            completedAt: Date()
        )
        toolManager.emit(.completed(
            jobID: job.id,
            result: ToolCallResult(content: "Error: Missing 'path' argument", isError: true),
            snapshot: job
        ))

        #expect(viewModel.isErroredResult(for: job))
        #expect(viewModel.statusTitle(for: job) == pluginLocalization.string("Failed"))
        #expect(viewModel.statusTitle(for: job) != pluginLocalization.string("Completed"))
    }

    @Test("completed 且 isError=false 的结果保持 Completed")
    func completedSuccessResultKeepsCompletedStatus() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)

        let job = ToolJob(
            id: "job-ok",
            conversationID: conversationID,
            toolCall: KitAgentTool.ToolCall(id: "call-ok", name: "read_image", arguments: "{\"path\":\"a.png\"}"),
            status: .completed,
            completedAt: Date()
        )
        toolManager.emit(.completed(
            jobID: job.id,
            result: ToolCallResult(content: "image", isError: false),
            snapshot: job
        ))

        #expect(!viewModel.isErroredResult(for: job))
        #expect(viewModel.statusTitle(for: job) == pluginLocalization.string("Completed"))
    }

    /// 回归 #960：任务进入 `.running` 后可能长时间没有任何事件，
    /// 只有计时刷新源存在，界面耗时才会继续走。
    @Test("运行中的任务启动计时刷新，进入终态后停止（**回归 #960**）")
    func tickingFollowsActiveJobs() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let startedAt = Date()
        let viewModel = ToolActivityViewModel(
            conversations: conversations,
            toolManager: toolManager,
            dateProvider: { startedAt }
        )
        #expect(!viewModel.isTicking, "没有任务时不应空转计时器")

        let running = ToolJob(
            id: "job-running",
            conversationID: conversationID,
            toolCall: KitAgentTool.ToolCall(id: "call-running", name: "run_command", arguments: "{}"),
            status: .running,
            startedAt: startedAt
        )
        toolManager.emit(.started(running))
        #expect(viewModel.isTicking, "运行中的任务必须驱动耗时刷新")

        var completed = running
        completed.status = .completed
        completed.completedAt = startedAt.addingTimeInterval(12)
        toolManager.emit(.completed(
            jobID: completed.id,
            result: ToolCallResult(content: "ok"),
            snapshot: completed
        ))
        #expect(!viewModel.isTicking, "全部终态后应停止计时，避免无意义的重绘")
        viewModel.cancel()
    }

    /// 静默期内 `now` 必须前进，耗时才会更新；终态后固定为最终耗时。
    @Test("静默运行中的任务耗时随当前时间增长，终态后固定（**回归 #960**）")
    func silentRunningJobDurationAdvancesThenFreezes() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let startedAt = Date()
        var clock = startedAt
        let viewModel = ToolActivityViewModel(
            conversations: conversations,
            toolManager: toolManager,
            dateProvider: { clock }
        )

        let running = ToolJob(
            id: "job-silent",
            conversationID: conversationID,
            toolCall: KitAgentTool.ToolCall(id: "call-silent", name: "run_command", arguments: "{}"),
            status: .running,
            startedAt: startedAt
        )
        toolManager.emit(.started(running))
        #expect(viewModel.elapsedDuration(for: running) == 0)

        // 数秒没有任何 output / progress 事件，只有计时器推进时间。
        clock = startedAt.addingTimeInterval(5)
        viewModel.tick()
        #expect(
            viewModel.elapsedDuration(for: running) == 5,
            "静默运行中的任务耗时没有随当前时间增长"
        )
        #expect(viewModel.formatDuration(5) == "5.0s")

        var completed = running
        completed.status = .completed
        completed.completedAt = startedAt.addingTimeInterval(12)
        toolManager.emit(.completed(
            jobID: completed.id,
            result: ToolCallResult(content: "ok"),
            snapshot: completed
        ))

        // 终态之后即使世界时间继续前进，耗时也固定为最终值。
        clock = startedAt.addingTimeInterval(90)
        viewModel.tick()
        #expect(viewModel.elapsedDuration(for: completed) == 12)
        #expect(viewModel.formatDuration(12) == "12.0s")
        viewModel.cancel()
    }

    /// 回归 #1260：高频 output 事件就地更新既有 Job，不应每条事件都全量重排，
    /// 排序与运行中计数必须保持稳定。
    @Test("高频 output 事件保持有序与运行计数（**回归 #1260**）")
    func outputBurstKeepsOrderAndActiveCount() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 2_000)
        let jobA = makeJob(id: "a", conversationID: conversationID, createdAt: t0)
        let jobB = makeJob(id: "b", conversationID: conversationID, createdAt: t1)

        // 乱序到达：先 B 后 A，仍应按 createdAt 升序排列。
        toolManager.emit(.started(jobB))
        toolManager.emit(.started(jobA))
        #expect(viewModel.jobs.map(\.id) == ["a", "b"])
        #expect(viewModel.activeCount == 2)

        var updated = jobA
        for i in 0..<100 {
            updated.latestOutput = "chunk-\(i)"
            updated.updatedAt = t0.addingTimeInterval(Double(i))
            toolManager.emit(.output(jobID: "a", stream: .stdout, chunk: "chunk-\(i)", snapshot: updated))
        }
        #expect(viewModel.jobs.map(\.id) == ["a", "b"])
        #expect(viewModel.jobs.first?.latestOutput == "chunk-99")
        #expect(viewModel.activeCount == 2)
        #expect(viewModel.activeCount == viewModel.activeJobs.count)

        updated.status = .completed
        updated.completedAt = t0.addingTimeInterval(120)
        toolManager.emit(.completed(jobID: "a", result: ToolCallResult(content: "ok"), snapshot: updated))
        #expect(viewModel.jobs.map(\.id) == ["a", "b"])
        #expect(viewModel.activeCount == 1)
        #expect(viewModel.activeCount == viewModel.activeJobs.count)
        viewModel.cancel()
    }

    /// 回归 #1260：新 Job 按创建时间插入到正确位置，与事件到达顺序无关。
    @Test("新 Job 按创建时间插入，与到达顺序无关（**回归 #1260**）")
    func newJobsInsertInSortedPosition() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)

        let j0 = makeJob(id: "j0", conversationID: conversationID, createdAt: Date(timeIntervalSince1970: 1_000))
        let j1 = makeJob(id: "j1", conversationID: conversationID, createdAt: Date(timeIntervalSince1970: 2_000))
        let j2 = makeJob(id: "j2", conversationID: conversationID, createdAt: Date(timeIntervalSince1970: 3_000))

        toolManager.emit(.created(j2))
        toolManager.emit(.created(j0))
        toolManager.emit(.created(j1))

        #expect(viewModel.jobs.map(\.id) == ["j0", "j1", "j2"])
        #expect(viewModel.activeCount == 3)
        viewModel.cancel()
    }

    /// 回归 #1260：排序键 createdAt 理论上可变，一旦变化必须恢复有序。
    @Test("createdAt 变化时恢复有序（**回归 #1260**）")
    func createdAtChangeRestoresOrder() {
        let conversationID = UUID()
        let conversations = StubConversationManager()
        conversations.selectedConversationID = conversationID
        let toolManager = StubToolManager()
        let viewModel = ToolActivityViewModel(conversations: conversations, toolManager: toolManager)
        let jobA = makeJob(id: "a", conversationID: conversationID, createdAt: Date(timeIntervalSince1970: 1_000))
        let jobB = makeJob(id: "b", conversationID: conversationID, createdAt: Date(timeIntervalSince1970: 2_000))
        toolManager.emit(.started(jobA))
        toolManager.emit(.started(jobB))
        #expect(viewModel.jobs.map(\.id) == ["a", "b"])

        var moved = jobA
        moved.createdAt = Date(timeIntervalSince1970: 3_000)
        toolManager.emit(.output(jobID: "a", stream: .stdout, chunk: "x", snapshot: moved))
        #expect(viewModel.jobs.map(\.id) == ["b", "a"])
        viewModel.cancel()
    }

    private func makeJob(
        id: String,
        conversationID: UUID,
        createdAt: Date,
        status: ToolJobStatus = .running
    ) -> ToolJob {
        ToolJob(
            id: id,
            conversationID: conversationID,
            toolCall: KitAgentTool.ToolCall(id: "call-\(id)", name: "run_command", arguments: "{}"),
            status: status,
            createdAt: createdAt,
            startedAt: createdAt
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

    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        NoopSelectedConversationObserverHandle()
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

    func selectConversation(id: UUID) { selectedConversationID = id }
    func deselectConversation() { selectedConversationID = nil }
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
