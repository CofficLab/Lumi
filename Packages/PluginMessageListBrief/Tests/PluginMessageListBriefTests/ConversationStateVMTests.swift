import Foundation
import Testing
@testable import PluginMessageListBrief

@Test @MainActor func conversationStateVMAcceptsOnlySelectedConversation() {
    let selectedConversationID = UUID()
    let otherConversationID = UUID()
    let activity = AgentActivityProjection(
        phase: .thinking,
        title: "正在思考…",
        detail: nil
    )
    let vm = ConversationStateVM()

    vm.updateSelectedConversation(selectedConversationID)
    vm.update(activity: activity, for: selectedConversationID)
    #expect(vm.activity == activity)

    vm.update(activity: nil, for: otherConversationID)
    #expect(vm.activity == activity)

    vm.updateSelectedConversation(otherConversationID)
    #expect(vm.activity == nil)
}
