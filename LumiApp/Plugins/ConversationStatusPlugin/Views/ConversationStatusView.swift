import SwiftUI

/// 会话状态消息视图组件
///
/// 显示当前会话的发送/流式/工具执行状态，动态在右侧栏底部显示。
struct ConversationStatusView: View {
    @EnvironmentObject var conversationVM: WindowConversationVM
    @EnvironmentObject var conversationSendStatusVM: WindowConversationStatusVM
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 当前会话 ID
    private var currentConversationId: UUID? {
        return conversationVM.selectedConversationId
    }

    /// 当前会话的状态消息（若有）
    private var statusMessage: ChatMessage? {
        guard let sid = currentConversationId else { return nil }
        return conversationSendStatusVM.statusMessage(for: sid)
    }

    var body: some View {
        Group {
            if projectVM.isProjectSelected, let message = statusMessage {
                StatusMessageRow(message: message)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeVM.activeChromeTheme.workspaceBackgroundColor().opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Conversation Status Area", table: "ConversationStatus"))
    }
}

/// 状态消息行视图
struct StatusMessageRow: View {
    let message: ChatMessage
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        HStack(spacing: 6) {
            // 状态图标
            Image(systemName: statusIconName)
                .font(.caption)
                .foregroundColor(statusIconColor)

            // 状态文本
            Text(message.content)
                .font(.caption)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .lineLimit(1)

            Spacer()
        }
    }

    /// 根据状态内容返回图标名称
    private var statusIconName: String {
        let content = message.content
        if content.contains("思考") {
            return "brain"
        } else if content.contains("接收") || content.contains("流式") {
            return "arrow.down.circle"
        } else if content.contains("工具") || content.contains("执行") {
            return "wrench"
        } else if content.contains("结束") {
            return "checkmark.circle"
        } else if content.contains("失败") || content.contains("❌") {
            return "xmark.circle"
        } else if content.contains("停止") || content.contains("⛔️") {
            return "stop.circle"
        } else if content.contains("✅") {
            return "checkmark.circle.fill"
        } else {
            return "arrow.triangle.2.circlepath"
        }
    }

    /// 根据状态内容返回图标颜色
    private var statusIconColor: Color {
        let content = message.content
        if content.contains("思考") {
            return .purple
        } else if content.contains("接收") || content.contains("流式") {
            return .blue
        } else if content.contains("工具") || content.contains("执行") {
            return .orange
        } else if content.contains("结束") || content.contains("✅") {
            return .green
        } else if content.contains("失败") || content.contains("❌") {
            return .red
        } else if content.contains("停止") || content.contains("⛔️") {
            return .yellow
        } else {
            return themeVM.activeChromeTheme.workspaceSecondaryTextColor()
        }
    }
}

// MARK: - Preview

#Preview("ConversationStatusView - With Status") {
    ConversationStatusView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 400, height: 100)
}

#Preview("ConversationStatusView - Empty") {
    ConversationStatusView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 400, height: 100)
}