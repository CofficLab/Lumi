import Foundation
@testable import KernelLumi

/// 测试用 `ConversationManaging` 实现。
///
/// 只维护发送编排测试关心的状态:选中会话、`createConversation` 调用计数。
/// 其余能力返回中性默认值(verbosity/effort/language 等)。
@MainActor
final class MockConversationManager: ConversationManaging {
    let log: OrchestrationEventLog?

    var selectedConversationID: UUID?
    var globalVerbosity: LumiResponseVerbosity = .defaultVerbosity

    /// `createConversation` 返回的会话 id。
    var nextCreatedConversationID = UUID()
    private(set) var createConversationCalls = 0

    init(log: OrchestrationEventLog? = nil, selectedConversationID: UUID? = nil) {
        self.log = log
        self.selectedConversationID = selectedConversationID
    }

    var conversations: [LumiConversationSummary] { [] }
    var currentTitle: String { "" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp") }

    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
        createConversationCalls += 1
        log?.record("createConversation")
        return nextCreatedConversationID
    }

    func selectConversation(id: UUID) { selectedConversationID = id }
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }
    func isSending(for conversationID: UUID?) -> Bool { false }
    func mockConversationIDs() -> [UUID] { [] }

    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) { globalVerbosity = verbosity }
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .defaultVerbosity }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}

    func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort { .defaultEffort }
    func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? { nil }
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}

    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}

    func language(for conversationID: UUID?) -> LumiConversationLanguage { .chinese }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
}
