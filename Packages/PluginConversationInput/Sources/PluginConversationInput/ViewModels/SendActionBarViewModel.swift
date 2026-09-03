import Foundation
import os
import ProviderConversation
import ProviderConversationState
import ProviderConversationInput
import ProviderMessageSender
import KitSuperLog

/// Manages the state and actions for the send/stop action bar.
///
/// The plugin owns this model and its observation lifecycle. Observers update
/// `state` when the input text or sending state changes; the view only renders
/// the model and invokes its actions.
///
/// - Precondition: Both `input` and `sender` must be non-nil. The caller
///   (`SendActionBarButton`) is responsible for nil-checking before instantiation.
@MainActor
@Observable
final class SendActionBarViewModel: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin-conversation-input", category: "SendActionBarButton")
    nonisolated public static let emoji = "🔘"
    nonisolated static let verbose = false

    private let input: any ConversationInputProviding
    private let sender: any MessageSendingProviding
    private let conversations: any ConversationManaging
    private let conversationState: any ConversationStateProviding

    private(set) var state: SendActionBarState

    // MARK: - Lifecycle

    init(
        input: any ConversationInputProviding,
        sender: any MessageSendingProviding,
        conversations: any ConversationManaging,
        conversationState: any ConversationStateProviding
    ) {
        self.input = input
        self.sender = sender
        self.conversations = conversations
        self.conversationState = conversationState
        self.state = SendActionBarState(
            isSending: conversationState.state(for: conversations.selectedConversationID ?? UUID()).isSending,
            canSend: Self.canSend(
                text: input.text,
                hasAttachments: !sender.pendingImageAttachments.isEmpty || !sender.pendingFileAttachments.isEmpty
            )
        )
    }

    // MARK: - State updates

    func updateInputText(_ text: String) {
        state.canSend = Self.canSend(
            text: text,
            hasAttachments: !sender.pendingImageAttachments.isEmpty || !sender.pendingFileAttachments.isEmpty
        )
    }

    func updateAttachments() {
        state.canSend = Self.canSend(
            text: input.text,
            hasAttachments: !sender.pendingImageAttachments.isEmpty || !sender.pendingFileAttachments.isEmpty
        )
    }

    func refreshConversationState() {
        guard let conversationID = conversations.selectedConversationID else {
            state.isSending = false
            return
        }
        state.isSending = conversationState.state(for: conversationID).isSending
    }

    // MARK: - Actions

    /// Cancel the current in-flight request.
    func cancel() {
        sender.cancelCurrentRequest()
        Self.logger.info("\(self.t)cancelled current request")
    }

    /// Send the current input text. Clears the input field on success.
    func send() {
        let trimmed = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachments = sender.pendingImageAttachments
        let fileAttachments = sender.pendingFileAttachments
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        Self.logger.info("\(self.t)sending message, length=\(trimmed.count)")
        input.text = ""
        input.errorMessage = nil

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await sender.commitUserMessageInBackground(
                        trimmed,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        conversationID: nil
                    ) else { return }
                    Self.logger.info("\(self.t)message attachments encoded and committed")
                    guard !commit.wasQueued else { return }
                    await sender.startTurn(for: commit)
                } catch {
                    Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
                    input.errorMessage = error.localizedDescription
                }
            }
            return
        }

        do {
            guard let commit = try sender.commitUserMessage(
                trimmed,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                conversationID: nil
            ) else { return }
            Self.logger.info("\(self.t)message committed successfully")
            guard !commit.wasQueued else { return }

            // 用户消息已经可见；AgentLoop 回合跟踪放到下一次 MainActor 调度。
            Task { @MainActor in
                await sender.startTurn(for: commit)
            }
        } catch {
            Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
            input.errorMessage = error.localizedDescription
        }
    }

    private static func canSend(text: String, hasAttachments: Bool) -> Bool {
        hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
