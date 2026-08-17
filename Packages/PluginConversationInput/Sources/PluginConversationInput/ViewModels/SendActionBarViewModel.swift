import Foundation
import os
import ProviderConversationInput
import ProviderMessageSender
import SuperLogKit

/// Manages the state and actions for the send/stop action bar.
///
/// Encapsulates subscription-based observation of input text and sending state
/// (the existential-type workaround), plus the send pipeline. Call `setup()`
/// when the view appears and `teardown()` when it disappears.
@MainActor
@Observable
final class SendActionBarViewModel: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin-conversation-input", category: "SendActionBarButton")
    nonisolated public static let emoji = "🔘"
    nonisolated static let verbose = true

    private let input: (any ConversationInputProviding)?
    private let sender: (any MessageSendingProviding)?

    // MARK: - Observation tokens

    private var textToken: (any TextInputObserverHandle)?
    private var sendingToken: (any SendingStateObserverHandle)?

    // MARK: - Revision counters (drive @Observable re-renders)

    @ObservationIgnored
    private var inputRevision = 0
    @ObservationIgnored
    private var senderRevision = 0

    // MARK: - Derived state

    var isSending: Bool {
        _ = senderRevision // track dependency for @Observable
        return sender?.isSending ?? false
    }

    var canSend: Bool {
        _ = inputRevision // track dependency for @Observable
        guard let input else { return false }
        return !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var state: SendActionBarState {
        SendActionBarState(isSending: isSending, canSend: canSend)
    }

    /// Non-nil when a required dependency is missing; explains which provider failed to resolve.
    let initializationError: String?

    var hasError: Bool { initializationError != nil }

    // MARK: - Lifecycle

    init(input: (any ConversationInputProviding)?, sender: (any MessageSendingProviding)?) {
        self.input = input
        self.sender = sender

        var missing: [String] = []
        if input == nil { missing.append("ConversationInputProviding") }
        if sender == nil { missing.append("MessageSendingProviding") }
        self.initializationError = missing.isEmpty ? nil
            : "Missing provider(s): \(missing.joined(separator: ", "))"

        if let initializationError {
            Self.logger.error("\(Self.onInit)failed ➡️ \(initializationError)")
        } else {
            Self.logger.info("\(Self.onInit)initialized")
        }
    }

    /// Subscribe to input text and sending state changes. Call in `onAppear`.
    func setup() {
        if Self.verbose {
            Self.logger.debug("\(self.t)setup — subscribing to input and sending state")
        }
        textToken = input?.addTextObserver { [weak self] _ in
            self?.inputRevision &+= 1
        }
        sendingToken = sender?.addSendingStateObserver { [weak self] _ in
            self?.senderRevision &+= 1
        }
    }

    /// Cancel all subscriptions. Call in `onDisappear`.
    func teardown() {
        textToken?.cancel()
        textToken = nil
        sendingToken?.cancel()
        sendingToken = nil
        if Self.verbose {
            Self.logger.debug("\(self.t)teardown — subscriptions released")
        }
    }

    // MARK: - Actions

    /// Cancel the current in-flight request.
    func cancel() {
        sender?.cancelCurrentRequest()
        Self.logger.info("\(self.t)cancelled current request")
    }

    /// Send the current input text. Clears the input field on success.
    func send() {
        guard let input, let sender else { return }
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
