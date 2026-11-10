import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import GoalTaskPlugin

// #696 回归：Goal 分叉提交开场指令时必须走显式附件重载并传空数组，
// 否则便捷重载会消费发送器全局挂起的图片/文件附件，把用户为下一条消息
// 暂存的附件偷走并清空。
@Suite("Goal Fork Attachment Isolation")
@MainActor
struct GoalForkAttachmentIsolationTests {

    /// 记录重载选择并模拟「挂起池被消费」的发送器替身。
    @MainActor
    private final class MessageSendingProvidingStub: MessageSendingProviding {

        struct ExplicitCall: Equatable {
            let text: String
            let imageAttachments: [UserImageAttachment]
            let fileAttachments: [UserFileAttachment]
            let conversationID: UUID?
        }

        /// 便捷重载被调用的次数。修复后必须为 0。
        private(set) var legacyCalls = 0
        /// 显式附件重载的调用记录。
        private(set) var explicitCalls: [ExplicitCall] = []
        /// 便捷重载「消费」掉的挂起附件数量，用于证明附件确实被偷走。
        private(set) var consumedPendingImageCount = 0
        private(set) var consumedPendingFileCount = 0

        private var pendingImages: [UserImageAttachment] = []
        private var pendingFiles: [UserFileAttachment] = []

        // MARK: - 挂起池

        var pendingImageAttachments: [UserImageAttachment] { pendingImages }
        var pendingFileAttachments: [UserFileAttachment] { pendingFiles }

        func addImageAttachment(_ attachment: UserImageAttachment) {
            pendingImages.append(attachment)
        }

        func removeImageAttachment(id: UUID) {
            pendingImages.removeAll { $0.id == id }
        }

        func clearImageAttachments() {
            pendingImages.removeAll()
        }

        func addFileAttachment(_ attachment: UserFileAttachment) {
            pendingFiles.append(attachment)
        }

        func removeFileAttachment(id: UUID) {
            pendingFiles.removeAll { $0.id == id }
        }

        func clearFileAttachments() {
            pendingFiles.removeAll()
        }

        // MARK: - 提交重载

        func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? {
            legacyCalls += 1
            // 真实实现的便捷重载会消费挂起池，替身照此模拟。
            consumedPendingImageCount = pendingImages.count
            consumedPendingFileCount = pendingFiles.count
            pendingImages.removeAll()
            pendingFiles.removeAll()
            return MessageSendCommit(conversationID: conversationID ?? UUID(), userMessageID: UUID())
        }

        func commitUserMessage(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) throws -> MessageSendCommit? {
            explicitCalls.append(
                ExplicitCall(
                    text: content,
                    imageAttachments: imageAttachments,
                    fileAttachments: fileAttachments,
                    conversationID: conversationID
                )
            )
            return MessageSendCommit(conversationID: conversationID ?? UUID(), userMessageID: UUID())
        }

        // MARK: - 未使用的协议成员

        var isSending: Bool { false }

        func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
            NoopSendingStateHandle()
        }

        func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }

        func cancelPendingMessage(id: UUID, in conversationID: UUID) {}

        func commitUserMessageInBackground(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) async throws -> MessageSendCommit? {
            fatalError("unused")
        }

        func startTurn(for commit: MessageSendCommit) async {}

        func sendMessage(_ content: String, conversationID: UUID?) async throws {}

        func sendMessage(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) async throws {}

        func cancelCurrentRequest() {}

        func resumeTurn(
            in conversationID: UUID,
            request: AgentTurnResumeRequest
        ) async throws -> AgentLoopOutcome {
            fatalError("unused")
        }
    }

    @MainActor
    private final class NoopSendingStateHandle: SendingStateObserverHandle {
        func cancel() {}
    }

    /// 仅用于满足适配器 init 的会话管理替身；本测试不会调用其能力。
    @MainActor
    private final class ConversationManagingStub: ConversationManaging {
        var conversations: [ConversationSummary] = []
        var selectedConversationID: UUID?
        var currentTitle: String = ""
        var dataDirectory: URL = FileManager.default.temporaryDirectory

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            fatalError("unused")
        }

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?,
            parentConversationID: UUID?
        ) throws -> UUID {
            fatalError("unused")
        }

        func selectConversation(id: UUID) {}

        func deselectConversation() {}

        func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
            NoopSelectedConversationObserverHandle()
        }

        func deleteConversation(id: UUID) {}

        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
            fatalError("unused")
        }

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

        var globalAutomationLevel: AutomationLevel { .chat }
        func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {}
        func automationLevel(for conversationID: UUID?) -> AutomationLevel { .chat }
        func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {}

        var globalLanguage: ConversationLanguage { .english }
        func setGlobalLanguage(_ language: ConversationLanguage) {}
        func language(for conversationID: UUID?) -> ConversationLanguage { .english }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    }

    @Test("分叉提交走显式附件重载且不消费挂起的图片/文件附件")
    func testForkCommitDoesNotConsumePendingAttachments() throws {
        let sender = MessageSendingProvidingStub()
        // 模拟用户已为「下一条消息」暂存了图片与文件附件。
        sender.addImageAttachment(
            UserImageAttachment(mimeType: "image/png", base64Data: "aGk=", fileName: "pending.png")
        )
        sender.addFileAttachment(
            UserFileAttachment(fileName: "pending.txt", mimeType: "text/plain", textContent: "pending")
        )

        let adapter = GoalForkCapabilityAdapter(
            conversations: ConversationManagingStub(),
            messageSender: sender
        )
        let conversationID = UUID()

        let commit = try adapter.commitUserMessage("hi", conversationID: conversationID)

        #expect(commit != nil)
        // 必须命中显式附件重载，且只命中一次。
        #expect(sender.explicitCalls.count == 1)
        // 便捷重载会把挂起池偷走，一次都不能出现。
        #expect(sender.legacyCalls == 0)

        let call = try #require(sender.explicitCalls.first)
        #expect(call.text == "hi")
        #expect(call.conversationID == conversationID)
        // 显式重载收到的附件数组必须为空，即不消费挂起池。
        #expect(call.imageAttachments.isEmpty)
        #expect(call.fileAttachments.isEmpty)
        #expect(sender.consumedPendingImageCount == 0)
        #expect(sender.consumedPendingFileCount == 0)
        // 用户暂存的附件必须原样留在池子里，等用户下一次发送。
        #expect(sender.pendingImageAttachments.count == 1)
        #expect(sender.pendingFileAttachments.count == 1)
    }
}
