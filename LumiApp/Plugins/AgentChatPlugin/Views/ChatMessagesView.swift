import MagicKit
import SwiftUI

/// 聊天消息列表视图组件
///
/// 支持多窗口模式，优先从 WindowState 获取当前窗口的会话选择，
/// 如果 WindowState 不可用，则回退到全局 ConversationVM。
struct ChatMessagesView: View {
    /// 窗口级状态（多窗口支持）
    @Environment(\.windowState) private var windowState
    
    /// 会话管理 ViewModel（全局，用于回退）
    @EnvironmentObject var conversationVM: ConversationVM
    
    /// 主题管理器
    @EnvironmentObject private var themeVM: ThemeVM

    /// 当前会话 ID（优先从 WindowState 获取）
    private var currentConversationId: UUID? {
        // 优先使用窗口级状态
        if let windowState = windowState,
           let conversationId = windowState.selectedConversationId {
            return conversationId
        }
        // 回退到全局 VM
        return conversationVM.selectedConversationId
    }

    var body: some View {
        Group {
            if currentConversationId != nil {
                MessageListView()
            } else {
                EmptyStateView()
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
