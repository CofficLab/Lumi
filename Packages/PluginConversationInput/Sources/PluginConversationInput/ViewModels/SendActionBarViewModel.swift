import Combine
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
    private var conversationStateCancellable: AnyCancellable?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?

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
            canSend: !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        conversationStateCancellable = conversationState.objectWillChange.sink { [weak self] _ in
            self?.refreshConversationState()
        }
        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.refreshConversationState()
        }
    }

    // MARK: - State updates

    func updateInputText(_ text: String) {
        state.canSend = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func refreshConversationState() {
        guard let conversationID = conversations.selectedConversationID else {
            state.isSending = false
            return
        }
        state.isSending = conversationState.state(for: conversationID).isSending
    }

    func stopObservingConversationState() {
        conversationStateCancellable?.cancel()
        conversationStateCancellable = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
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
        guard !trimmed.isEmpty else { return }

        Self.logger.info("\(self.t)sending message, length=\(trimmed.count)")
        input.text = ""
        input.errorMessage = nil

        Task { @MainActor in
            do {
                try await sender.sendMessage(trimmed, conversationID: nil)
                Self.logger.info("\(self.t)message sent successfully")
            } catch {
                Self.logger.error("\(self.t)send failed ➡️ \(error.localizedDescription, privacy: .public)")
                input.errorMessage = error.localizedDescription
            }
        }
    }
}
