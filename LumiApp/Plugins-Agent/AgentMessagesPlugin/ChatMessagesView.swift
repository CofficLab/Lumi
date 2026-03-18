import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图组件
struct ChatMessagesView: View, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true

    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM

    /// 权限请求 ViewModel
    @EnvironmentObject var permissionRequestViewModel: PermissionRequestVM

    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateVM

    /// 思考状态 ViewModel
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateVM

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentVM

    /// 当前选中的会话 ID
    private var selectedConversationId: UUID? {
        ConversationVM.selectedConversationId
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
            if processingStateViewModel.hasActiveLoading || thinkingStateViewModel.isThinking {
                statusOverlay
            }
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

    private var statusOverlay: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .foregroundStyle(.secondary)
            Text(statusOverlayText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusOverlayText: String {
        if processingStateViewModel.hasActiveLoading {
            return processingStateViewModel.statusText
        }
        if thinkingStateViewModel.isThinking {
            return "思考中…"
        }
        return ""
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
