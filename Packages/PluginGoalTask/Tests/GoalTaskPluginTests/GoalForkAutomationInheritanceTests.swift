import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import GoalTaskPlugin

// #772 回归：Goal 分叉适配器必须从「源对话（当前选中）」读自动化等级，
// 并把等级写到分叉出的新对话上，而不是沿用全局 New Chat 默认（可能是无工具的 Chat）。
@Suite("Goal Fork Automation Inheritance")
@MainActor
struct GoalForkAutomationInheritanceTests {

    /// 记录自动化等级读写的会话管理替身。
    @MainActor
    private final class RecordingConversationManagingStub: ConversationManaging {
        var conversations: [ConversationSummary] = []
        var selectedConversationID: UUID?
        var currentTitle: String = ""
        var dataDirectory: URL = FileManager.default.temporaryDirectory

        /// 全局 New Chat 默认；故意设为无工具的 Chat，证明源等级不被它覆盖。
        var globalAutomationLevel: AutomationLevel = .chat
        /// 各对话已绑定的自动化等级。
        var levels: [UUID: AutomationLevel] = [:]
        /// setAutomationLevel 的调用记录。
        private(set) var automationSets: [(level: AutomationLevel, conversationID: UUID?)] = []

        func automationLevel(for conversationID: UUID?) -> AutomationLevel {
            guard let conversationID else { return globalAutomationLevel }
            return levels[conversationID] ?? globalAutomationLevel
        }

        func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {
            automationSets.append((automationLevel, conversationID))
            if let conversationID { levels[conversationID] = automationLevel }
        }

        // MARK: - 未使用的协议成员

        func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
            fatalError("unused")
        }
        func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?, parentConversationID: UUID?) throws -> UUID {
            fatalError("unused")
        }
        func selectConversation(id: UUID) {}
        func deselectConversation() {}
        func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
            NoopSelectedHandle()
        }
        func deleteConversation(id: UUID) {}
        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { fatalError("unused") }
        func markConversationActive(id: UUID, messageDate: Date) {}
        func isSending(for conversationID: UUID?) -> Bool { false }
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

        var globalVerbosity: ResponseVerbosity { .defaultVerbosity }
        func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {}
        func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .defaultVerbosity }

        var globalReasoningEffort: ReasoningEffort? { .defaultEffort }
        func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {}
        func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .defaultEffort }
        func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { .defaultEffort }
        func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {}
        func clearReasoningEffort(for conversationID: UUID?) {}

        func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {}

        var globalLanguage: ConversationLanguage { .english }
        func setGlobalLanguage(_ language: ConversationLanguage) {}
        func language(for conversationID: UUID?) -> ConversationLanguage { .english }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    }

    @MainActor
    private final class NoopSelectedHandle: SelectedConversationObserverHandle {
        func cancel() {}
    }

    /// 仅满足适配器 init 的发送器替身；本测试不触发任何发送。
    @MainActor
    private final class UnusedSenderStub: MessageSendingProviding {
        var isSending: Bool { false }
        var pendingImageAttachments: [UserImageAttachment] { [] }
        var pendingFileAttachments: [UserFileAttachment] { [] }
        func addImageAttachment(_ attachment: UserImageAttachment) {}
        func removeImageAttachment(id: UUID) {}
        func clearImageAttachments() {}
        func addFileAttachment(_ attachment: UserFileAttachment) {}
        func removeFileAttachment(id: UUID) {}
        func clearFileAttachments() {}
        func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
            NoopSendingHandle()
        }
        func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }
        func cancelPendingMessage(id: UUID, in conversationID: UUID) {}
        func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? { fatalError("unused") }
        func commitUserMessage(_ content: String, imageAttachments: [UserImageAttachment], fileAttachments: [UserFileAttachment], conversationID: UUID?) throws -> MessageSendCommit? { fatalError("unused") }
        func commitUserMessageInBackground(_ content: String, imageAttachments: [UserImageAttachment], fileAttachments: [UserFileAttachment], conversationID: UUID?) async throws -> MessageSendCommit? { fatalError("unused") }
        func startTurn(for commit: MessageSendCommit) async {}
        func sendMessage(_ content: String, conversationID: UUID?) async throws {}
        func sendMessage(_ content: String, imageAttachments: [UserImageAttachment], fileAttachments: [UserFileAttachment], conversationID: UUID?) async throws {}
        func cancelCurrentRequest() {}
        func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { fatalError("unused") }
    }

    @MainActor
    private final class NoopSendingHandle: SendingStateObserverHandle {
        func cancel() {}
    }

    private func makeAdapter(_ conversations: RecordingConversationManagingStub) -> GoalForkCapabilityAdapter {
        GoalForkCapabilityAdapter(conversations: conversations, messageSender: UnusedSenderStub())
    }

    @Test("sourceAutomationLevel 读选中源对话的等级，而非全局 New Chat 默认（#772）")
    func testSourceLevelReadsSelectedConversationNotGlobal() {
        let conversations = RecordingConversationManagingStub()
        let sourceID = UUID()
        conversations.selectedConversationID = sourceID
        conversations.levels[sourceID] = .autonomous
        // 全局默认是无工具的 Chat；若适配器误读全局就会拿到 .chat。
        conversations.globalAutomationLevel = .chat

        let level = makeAdapter(conversations).sourceAutomationLevel()

        #expect(level == .autonomous)
        #expect(level.allowsTools == true)
    }

    @Test("applyAutomationLevel 把等级写到分叉出的目标对话（#772）")
    func testApplyLevelTargetsForkedConversation() {
        let conversations = RecordingConversationManagingStub()
        let newID = UUID()

        makeAdapter(conversations).applyAutomationLevel(.build, to: newID)

        #expect(conversations.automationSets.count == 1)
        #expect(conversations.automationSets.first?.level == .build)
        #expect(conversations.automationSets.first?.conversationID == newID)
        #expect(conversations.levels[newID] == .build)
    }

    @Test("未选中源对话时回落到全局默认（边界）")
    func testSourceLevelFallsBackToGlobalWhenNoSelection() {
        let conversations = RecordingConversationManagingStub()
        conversations.selectedConversationID = nil
        conversations.globalAutomationLevel = .build

        let level = makeAdapter(conversations).sourceAutomationLevel()

        #expect(level == .build)
    }
}