import LumiKernel
import SwiftUI

struct ConversationTitleSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        let selectedID = coordinator.selectedConversationID

        ConversationTitleHeaderView(
            title: coordinator.selectedTitle(for: selectedID),
            isSending: coordinator.chatService.isSending(for: selectedID)
        )
    }
}
