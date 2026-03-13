import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图组件
struct ChatMessagesView: View, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// 权限请求 ViewModel
    @EnvironmentObject var permissionRequestViewModel: PermissionRequestViewModel

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 当前选中的会话 ID
    private var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    /// 是否已选择会话
    private var hasSelectedConversation: Bool {
        selectedConversationId != nil
    }

    var body: some View {
        Group {
            if hasSelectedConversation {
                MessageListView()
                    .overlay(alignment: .top) { messageOverlay }
            } else {
                EmptyStateView()
            }
        }
        .background(.background.opacity(0.8))
    }

    /// 消息叠加层视图：显示深度警告和权限请求
    private var messageOverlay: some View {
        VStack(spacing: 8) {
            DepthWarningBanner()
            if let request = permissionRequestViewModel.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: { Task { await agentProvider.respondToPermissionRequest(allowed: true) } },
                    onDeny: { Task { await agentProvider.respondToPermissionRequest(allowed: false) } }
                )
            }
        }
        .padding()
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
