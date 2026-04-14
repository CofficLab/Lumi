import SwiftUI

struct HistoryDBStatusBarView: View {
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM
    @EnvironmentObject private var conversationVM: ConversationVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: HistoryDBDetailView(
                chatHistoryVM: chatHistoryVM,
                conversationVM: conversationVM
            ),
            popoverWidth: 980,
            id: "history-db-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "tablecells")
                    .font(.system(size: 10))
                Text(String(localized: "History DB", table: "HistoryDBStatusBar"))
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
