import KitAgentTool
import LumiUI
import ProviderChatSection
import ProviderConversation
import ProviderToolManager
import SwiftUI

/// A pending high-risk authorization that can be displayed independently of
/// the V1 message-list renderer.
struct RiskApprovalPendingInteraction: Equatable, Sendable {
    let toolCall: ToolCall
    let conversationID: UUID
    let turnID: UUID?

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

/// Owns the V1 fixed-area presentation of pending tool authorization.
@MainActor
final class RiskApprovalChatViewModel: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var verbosity: ResponseVerbosity
    @Published private(set) var pendingApprovals: [UUID: RiskApprovalPendingInteraction] = [:]

    private let conversations: any ConversationManaging
    private let toolManager: any ToolManagerProviding
    private var toolManagerObserver: (any ToolManagerObserverHandle)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var conversationObserver: (any ConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding
    ) {
        self.conversations = conversations
        self.toolManager = toolManager
        self.selectedConversationID = conversations.selectedConversationID
        self.verbosity = conversations.verbosity(for: conversations.selectedConversationID)

        toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in
            self?.consume(event)
        }
        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] conversationID in
            self?.synchronizeSelection(conversationID)
        }
        conversationObserver = conversations.addConversationObserver { [weak self] event in
            guard case let .verbosityChanged(conversationID) = event,
                  conversationID == nil || conversationID == self?.selectedConversationID else { return }
            self?.synchronizeSelection(self?.selectedConversationID)
        }
    }

    var visibleInteraction: RiskApprovalPendingInteraction? {
        let interaction = selectedConversationID.flatMap { pendingApprovals[$0] }
        guard Self.shouldShow(
            verbosity: verbosity,
            selectedConversationID: selectedConversationID,
            interaction: interaction
        ) else { return nil }
        return interaction
    }

    static func shouldShow(
        verbosity: ResponseVerbosity,
        selectedConversationID: UUID?,
        interaction: RiskApprovalPendingInteraction?
    ) -> Bool {
        RiskApprovalPendingInteraction.shouldShow(
            verbosity: verbosity,
            selectedConversationID: selectedConversationID,
            interaction: interaction
        )
    }

    func cancel() {
        toolManagerObserver?.cancel()
        toolManagerObserver = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        pendingApprovals.removeAll()
    }

    func consume(_ event: ToolManagerEvent) {
        switch event {
        case let .authorizationRequired(conversationID, turnID, toolCall):
            guard (toolManager.riskLevel(for: toolCall) ?? .high).requiresPermission else { return }
            pendingApprovals[conversationID] = RiskApprovalPendingInteraction(
                toolCall: toolCall,
                conversationID: conversationID,
                turnID: turnID
            )
        case let .completed(conversationID, _, toolCall, _),
             let .authorizedCompleted(conversationID, _, toolCall, _):
            guard pendingApprovals[conversationID]?.toolCall.id == toolCall.id else { return }
            pendingApprovals.removeValue(forKey: conversationID)
        default:
            break
        }
    }

    private func synchronizeSelection(_ conversationID: UUID?) {
        selectedConversationID = conversationID
        verbosity = conversations.verbosity(for: conversationID)
    }
}

/// V1 fallback. V2/V3 render the same interaction through ToolApprovalRowRenderer.
struct RiskApprovalChatSectionView: View {
    @ObservedObject var viewModel: RiskApprovalChatViewModel

    var body: some View {
        if let interaction = viewModel.visibleInteraction,
           let request = ToolApprovalBridge.shared.permissionRequest(for: interaction.toolCall) {
            ToolApprovalPendingView(
                request: request,
                toolCall: interaction.toolCall,
                conversationID: interaction.conversationID
            )
            .id(interaction.toolCall.id)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }
}
