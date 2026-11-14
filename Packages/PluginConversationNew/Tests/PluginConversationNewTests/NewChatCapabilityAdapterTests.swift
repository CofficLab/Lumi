import Foundation
import KitAgentTool
import ProviderConversation
import Testing
@testable import PluginConversationNew

/// `NewChatCapabilityAdapter.restoreSelection` 的回归（**#260**）。
///
/// 工具契约是「回合内只备料、不切换选中态」：创建顶层对话会抢占选中态，
/// 工具随后用调用前的 `previousSelection` 恢复。当调用前处于「新建会话」
/// 未选中态（nil）时，恢复必须显式取消选择，而不是无操作把用户甩进空对话。
@Suite("NewChatCapabilityAdapter（#260）")
@MainActor
struct NewChatCapabilityAdapterTests {

    @Test("恢复 nil 选中态必须取消选择，而不是无操作")
    func restoreNilSelectionDeselects() {
        let manager = RecordingConversationManager()
        // 复刻内核：创建顶层对话后选中态被抢到新对话上。
        let created = try? manager.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)
        #expect(created != nil)
        #expect(manager.selectedConversationID != nil, "前置条件：创建后应处于选中态")

        let adapter = NewChatCapabilityAdapter(conversations: manager)
        adapter.restoreSelection(to: nil)

        #expect(manager.deselectCount == 1, "nil 恢复必须调用 deselectConversation")
        #expect(manager.selectedConversationID == nil, "恢复后应回到未选中态")
    }

    @Test("恢复非 nil 选中态切换到该对话，且不取消选择")
    func restoreNonNilSelectionSelects() {
        let manager = RecordingConversationManager()
        let original = UUID()
        let adapter = NewChatCapabilityAdapter(conversations: manager)

        adapter.restoreSelection(to: original)

        #expect(manager.selectedIDs == [original], "非 nil 恢复应切换到原对话")
        #expect(manager.selectedConversationID == original)
        #expect(manager.deselectCount == 0, "非 nil 恢复不得取消选择")
    }

    @Test("工具经适配器创建对话后保留新建会话的未选中态")
    func toolPreservesNilSelectionThroughAdapter() async throws {
        let manager = RecordingConversationManager()
        #expect(manager.selectedConversationID == nil, "前置条件：用户处于新建会话未选中态")

        let adapter = NewChatCapabilityAdapter(conversations: manager)
        let tool = CreateNewConversationTool(conversations: adapter)
        _ = try await tool.execute(arguments: ["task": ToolArgument("Do an unrelated task here")])

        #expect(manager.createdCount == 1, "工具应创建一个顶层对话")
        #expect(manager.selectedConversationID == nil, "回合结束后不得把用户甩进新建的空对话")
        #expect(manager.deselectCount == 1, "nil 恢复必须经适配器取消选择")
    }
}

/// 记录选择/取消选择调用的 in-memory `ConversationManaging` 替身。
///
/// 只覆盖协议中无默认实现的成员；`createConversation` 复刻内核「创建即选中」行为。
@MainActor
private final class RecordingConversationManager: ConversationManaging {
    private(set) var summaries: [ConversationSummary] = []
    private(set) var selected: UUID?
    private(set) var deselectCount = 0
    private(set) var selectedIDs: [UUID] = []
    private(set) var createdCount = 0

    var conversations: [ConversationSummary] { summaries }
    var selectedConversationID: UUID? { selected }
    var currentTitle: String { summaries.first(where: { $0.id == selected })?.title ?? "" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginConversationNewTests") }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        let id = UUID()
        summaries.append(ConversationSummary(
            id: id,
            title: title,
            createdAt: Date(),
            updatedAt: Date(),
            projectPath: projectPath
        ))
        createdCount += 1
        // 复刻内核行为：顶层对话创建后自动成为选中态。
        selected = id
        return id
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try createConversation(title: title, projectPath: projectPath, providerID: providerID, modelName: modelName)
    }

    func selectConversation(id: UUID) {
        selectedIDs.append(id)
        selected = id
    }

    func deselectConversation() {
        deselectCount += 1
        selected = nil
    }

    func deleteConversation(id: UUID) { summaries.removeAll { $0.id == id } }

    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let index = summaries.firstIndex(where: { $0.id == conversationID }) else { return false }
        summaries[index].title = title
        return true
    }

    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }

    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    var globalVerbosity: ResponseVerbosity { .brief }
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {}
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .brief }
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}

    var globalReasoningEffort: ReasoningEffort? { nil }
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {}
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .medium }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { .medium }
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}

    var globalAutomationLevel: AutomationLevel { .chat }
    func setGlobalAutomationLevel(_ level: AutomationLevel) {}
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { .chat }
    func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) {}

    var globalLanguage: ConversationLanguage { .english }
    func setGlobalLanguage(_ language: ConversationLanguage) {}
    func language(for conversationID: UUID?) -> ConversationLanguage { .english }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}

    @discardableResult
    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        NoopSelectedConversationObserverHandle()
    }
}