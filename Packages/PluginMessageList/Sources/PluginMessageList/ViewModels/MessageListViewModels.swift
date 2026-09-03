import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming

/// Plugin-owned routing state for the MessageList root view.
@MainActor
final class MessageListRootViewModel: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var verbosity: ResponseVerbosity

    private let services: MessageListServices

    init(services: MessageListServices) {
        self.services = services
        selectedConversationID = services.selectedConversationID
        verbosity = services.verbosity(for: services.selectedConversationID)
    }

    func handleSelectedConversationChange(_ conversationID: UUID?) {
        selectedConversationID = conversationID
        verbosity = services.verbosity(for: conversationID)
    }

    func handleConversationChange() {
        verbosity = services.verbosity(for: selectedConversationID)
    }
}

/// All MessageList ViewModels are created and retained by `MessageListPlugin`.
@MainActor
final class MessageListViewModels {
    let root: MessageListRootViewModel
    let v1: ListV1ViewModel
    let v2: ListV2ViewModel
    let v3: ListV3ViewModel
    let guide: MessageListGuideState

    init(services: MessageListServices, guide: MessageListGuideState) {
        root = MessageListRootViewModel(services: services)
        v1 = ListV1ViewModel(services: services)
        v2 = ListV2ViewModel(services: services)
        v3 = ListV3ViewModel(services: services)
        self.guide = guide
    }

    func handleMessageChange(_ change: MessageChange) {
        v1.handleMessageChange(change)
        v2.handleMessageChange(change)
        v3.handleMessageChange(change)
    }

    func handleSelectedConversationChange(_ conversationID: UUID?) {
        root.handleSelectedConversationChange(conversationID)
        v1.handleSelectedConversationChange(conversationID)
        v2.handleSelectedConversationChange(conversationID)
        v3.handleSelectedConversationChange(conversationID)
    }

    func handleConversationChange() {
        root.handleConversationChange()
        v2.refreshConversationSettingsIfNeeded()
        v3.refreshConversationSettingsIfNeeded()
    }

    func handleConversationStateChange(_ event: ConversationStateEvent) {
        v2.handleConversationStateChange(event)
        v3.handleConversationStateChange(event)
    }

    func handleStreamingChange(_ change: MessageStreamingChange) {
        v1.handleStreamingChange(change)
        v2.handleStreamingChange(change)
        v3.handleStreamingChange(change)
    }
}
