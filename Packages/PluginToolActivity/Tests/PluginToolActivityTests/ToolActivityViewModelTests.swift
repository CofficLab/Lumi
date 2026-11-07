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
