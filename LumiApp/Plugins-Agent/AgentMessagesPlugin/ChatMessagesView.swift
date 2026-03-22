import MagicKit
import SwiftUI

/// 聊天消息列表视图组件
struct ChatMessagesView: View {
    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM

    var body: some View {
        Group {
            if ConversationVM.selectedConversationId != nil {
                MessageListView()
            } else {
                EmptyStateView()
            }
        }
        .background(.background.opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("聊天消息区域")
    }
}

// MARK: - Preview

#Preview("ChatMessagesView - Small") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("ChatMessagesView - Large") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}
