import Foundation
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// The interaction data needed by both the V1 chat item and the V2/V3 tool row.
struct AskUserPendingInteraction: Equatable, Sendable {
    let response: AskUserPendingResponse
    let toolCallID: String
    let conversationID: UUID
    let initialAnswer: String?

    /// Suspension payloads are owned by the agent loop, so the chat UI does not
    /// need to inspect the message list or duplicate tool-call lookup logic.
    static func from(suspension: AgentLoopSuspension) -> Self? {
        guard suspension.kind == "userInput",
              let toolCallID = suspension.toolCallID,
              !toolCallID.isEmpty,
              let data = suspension.payload.data(using: .utf8),
              let response = try? JSONDecoder().decode(
                  AskUserPendingResponse.self,
                  from: data
              ) else {
            return nil
        }
        return Self(
            response: response,
            toolCallID: toolCallID,
            conversationID: suspension.conversationID,
            initialAnswer: nil
        )
    }

    static func shouldShow(
        verbosity: ResponseVerbosity,
        selectedConversationID: UUID?,
        interaction: Self?
    ) -> Bool {
        guard verbosity == .brief,
              let selectedConversationID,
              let interaction else { return false }
        return selectedConversationID == interaction.conversationID
    }
}

/// Owns the currently pending ask_user interaction for the selected chat.
@MainActor
final class AskUserChatViewModel: ObservableObject {
    @Published private(set) var interaction: AskUserPendingInteraction?
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var verbosity: ResponseVerbosity = .standard

    private let conversations: any ConversationManaging
    private let agentLoop: any AgentLoopProviding
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?
    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    init(
        conversations: any ConversationManaging,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.agentLoop = agentLoop
        self.selectedConversationID = conversations.selectedConversationID
        self.verbosity = conversations.verbosity(for: conversations.selectedConversationID)
        synchronize()

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.synchronize()
        }
        conversationObserver = conversations.addConversationObserver { [weak self] event in
            guard case .verbosityChanged = event else { return }
            self?.synchronize()
        }
        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
        interaction = nil
        selectedConversationID = nil
        verbosity = .standard
    }

    private func handle(_ event: AgentLoopEvent) {
        let conversationID: UUID
        switch event {
        case let .started(id, _),
             let .toolCallsReceived(id, _, _, _),
             let .llmResponseReceived(id, _, _),
             let .suspended(id, _, _),
             let .completed(id, _),
             let .failed(id, _, _),
             let .cancelled(id, _):
            conversationID = id
        }

        guard conversationID == conversations.selectedConversationID else { return }
        synchronize()
    }

    private func synchronize() {
        let conversationID = conversations.selectedConversationID
        selectedConversationID = conversationID
        verbosity = conversations.verbosity(for: conversationID)

        guard let conversationID,
              verbosity == .brief,
              let suspension = agentLoop.suspension(for: conversationID),
              let next = AskUserPendingInteraction.from(suspension: suspension)
        else {
            interaction = nil
            return
        }
        interaction = next
    }
}

/// ChatSection contribution used only as a visible V1 fallback for pending
/// user input. V2/V3 continue to render the interaction inside the tool row.
struct AskUserChatSectionView: View {
    @ObservedObject var viewModel: AskUserChatViewModel

    var body: some View {
        if let interaction = viewModel.interaction,
           AskUserPendingInteraction.shouldShow(
               verbosity: viewModel.verbosity,
               selectedConversationID: viewModel.selectedConversationID,
               interaction: interaction
           ) {
            AskUserPendingView(interaction: interaction)
                .id(interaction.toolCallID)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }
}
