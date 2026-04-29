import MagicKit
import SwiftUI

/// 聊天消息列表视图组件
struct ChatMessagesView: View {
    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM
    /// 主题管理器
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if ConversationVM.selectedConversationId != nil {
                MessageListView()
            } else {
                EmptyStateView()
            }
        }
        .background(themeManager.activeAppTheme.workspaceBackgroundColor().opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Chat Messages Area", table: "AgentMessages"))
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
