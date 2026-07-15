import LumiChatKit
import LumiUI
import SwiftUI

struct StatusBarView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        StatusBarHoverContainer(
            detailView: SidebarView(
                conversationIdProvider: { coordinator.selectedConversationID },
                backgroundColorProvider: { Color.clear }
            ),
            popoverWidth: 360,
            id: "auto-task-panel"
        ) {
            Image(systemName: "checklist")
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}
