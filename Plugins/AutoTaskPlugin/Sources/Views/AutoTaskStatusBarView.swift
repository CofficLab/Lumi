import LumiCoreKit
import LumiUI
import SwiftUI

struct AutoTaskStatusBarView: View {
    let chatService: any LumiChatServicing

    var body: some View {
        StatusBarHoverContainer(
            detailView: AutoTaskSidebarView(
                conversationIdProvider: { chatService.selectedConversationID },
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
