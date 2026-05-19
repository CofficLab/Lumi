import SwiftUI

struct HistoryDBStatusBarView: View {
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: HistoryDBDetailView(
                chatHistoryVM: chatHistoryVM,
                conversationVM: conversationVM
            ),
            popoverWidth: 980,
            id: "history-db-status"
        ) {
            Image(systemName: "tablecells")
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}
