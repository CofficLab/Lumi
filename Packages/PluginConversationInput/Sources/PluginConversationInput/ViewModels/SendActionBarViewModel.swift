import Foundation
import os
import KitSuperLog

/// Manages the state and actions for the send/stop action bar.
///
/// The plugin owns this model and its observation lifecycle. Observers update
/// `state` when the input text or sending state changes; the view only renders
/// the model and invokes its actions. All external operations go through
/// `ConversationInputCapability`.
@MainActor
@Observable
final class SendActionBarViewModel: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin-conversation-input", category: "SendActionBarButton")
    nonisolated public static let emoji = "🔘"
    nonisolated static let verbose = true

    private let capability: any ConversationInputCapability

    private(set) var state: SendActionBarState

    // MARK: - Lifecycle

    init(capability: any ConversationInputCapability) {
        self.capability = capability
        self.state = SendActionBarState(
            isSending: capability.isSending(for: capability.selectedConversationID),
            canSend: Self.canSend(
                text: capability.text,
                hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
            )
        )
    }

    // MARK: - State updates

    func updateInputText(_ text: String) {
        state.canSend = Self.canSend(
            text: text,
            hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
        )
    }

    func updateAttachments() {
        state.canSend = Self.canSend(
            text: capability.text,
            hasAttachments: !capability.pendingImageAttachments.isEmpty || !capability.pendingFileAttachments.isEmpty
        )
    }

    func refreshConversationState() {
        guard let conversationID = capability.selectedConversationID else {
            state.isSending = false
            return
        }
        state.isSending = capability.isSending(for: conversationID)
    }

    // MARK: - Actions

    /// Cancel the current in-flight request.
    func cancel() {
        capability.cancelCurrentRequest()
        Self.logger.info("\(self.t)cancelled current request")
    }

    /// Send the current input text. Clears the input field on success.
    func send() {
        let trimmed = capability.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachments = capability.pendingImageAttachments
        let fileAttachments = capability.pendingFileAttachments
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else { return }

        Self.logger.info("\(self.t)sending message, length=\(trimmed.count)")
        capability.text = ""
        capability.errorMessage = nil

        if hasAttachments {
            Task { @MainActor in
                do {
                    guard let commit = try await capability.commitUserMessageInBackground(
                        trimmed,
                        imageAttachments: imageAttachments,
                        fileAttachments: fileAttachments,
                        conversationID: nil
                    ) else { return }
                    Self.logger.info("\(self.t)message attachments encoded and committed")
                    guard !commit.wasQueued else { return }
                    await capability.startTurn(for: commit)
                } catch {
                    Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
                    capability.errorMessage = error.localizedDescription
                }
            }
            return
        }

        do {
            guard let commit = try capability.commitUserMessage(
                trimmed,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                conversationID: nil
            ) else { return }
            Self.logger.info("\(self.t)message committed successfully")
            guard !commit.wasQueued else { return }

            // 用户消息已经可见；AgentLoop 回合跟踪放到下一次 MainActor 调度。
            Task { @MainActor in
                await capability.startTurn(for: commit)
            }
        } catch {
            Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
            capability.errorMessage = error.localizedDescription
        }
    }

    private static func canSend(text: String, hasAttachments: Bool) -> Bool {
        hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
