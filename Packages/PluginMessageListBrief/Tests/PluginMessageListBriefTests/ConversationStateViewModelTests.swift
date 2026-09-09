import Foundation
import Testing
@testable import PluginMessageListBrief

@Test @MainActor func conversationStateViewModelAcceptsOnlySelectedConversation() {
    let selectedConversationID = UUID()
    let otherConversationID = UUID()
    let activity = AgentActivityProjection(
        phase: .thinking,
        title: "正在思考…",
        detail: nil
    )
    let viewModel = ConversationStateViewModel()

    viewModel.updateSelectedConversation(selectedConversationID)
    viewModel.update(activity: activity, for: selectedConversationID)
    #expect(viewModel.activity == activity)

    viewModel.update(activity: nil, for: otherConversationID)
    #expect(viewModel.activity == activity)

    viewModel.updateSelectedConversation(otherConversationID)
    #expect(viewModel.activity == nil)
}
