import SwiftUI

/// 聊天消息列表视图组件
///
/// 支持多窗口模式，优先从 WindowContainer 获取当前窗口的会话选择，
/// 如果 WindowContainer 不可用，则回退到全局 WindowConversationVM。
struct ChatMessagesView: View {
    /// 会话管理 ViewModel（窗口级）
    @EnvironmentObject var conversationVM: WindowConversationVM
    @EnvironmentObject var projectVM: WindowProjectVM

    /// 主题管理器
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 当前会话 ID（优先从 WindowContainer 获取）
    private var currentConversationId: UUID? {
        return conversationVM.selectedConversationId
    }

    var body: some View {
        Group {
            if !projectVM.isProjectSelected {
                VStack {}
                    .frame(maxHeight: .infinity)
            } else {
                if currentConversationId != nil {
                    MessageListView()
                } else {
                    EmptyStateView()
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Chat Messages Area", table: "AgentChat"))
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
