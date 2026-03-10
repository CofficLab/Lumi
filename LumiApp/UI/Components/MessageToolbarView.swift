import SwiftUI

/// 消息工具按钮行组件
/// 显示在每条消息底部的一排操作按钮
struct MessageToolbarView: View {
    let message: ChatMessage
    /// 是否显示在助手消息上
    let isAssistantMessage: Bool
    
    @EnvironmentObject private var agentProvider: AgentProvider
    @State private var showCopyFeedback = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 复制按钮
            CopyMessageButton(
                content: message.content,
                showFeedback: $showCopyFeedback
            )

            if canResend {
                Button(action: resend) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text("重发")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .help("重新发送该消息")
            }
            
            // 未来可以添加更多按钮
            Spacer()
        }
        .padding(.top, 4)
        .padding(.leading, 2)
    }

    private var canResend: Bool {
        // 只允许重发用户消息；工具输出/系统消息/助手消息不提供重发入口
        message.role == .user && message.toolCallID == nil
    }

    private func resend() {
        agentProvider.sendMessage(input: message.content, images: [])
    }
}

// MARK: - Copy Message Button

/// 复制消息内容按钮
struct CopyMessageButton: View {
    let content: String
    @Binding var showFeedback: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .medium))
                if showFeedback {
                    Text("已复制")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(buttonColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .help("复制消息内容")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconName: String {
        showFeedback ? "checkmark" : "doc.on.doc"
    }
    
    private var buttonColor: Color {
        if showFeedback {
            return .green
        }
        return DesignTokens.Color.semantic.textSecondary.opacity(0.8)
    }
    
    private var backgroundColor: Color {
        if showFeedback {
            return Color.green.opacity(0.1)
        }
        return isHovered ? DesignTokens.Color.semantic.textSecondary.opacity(0.08) : DesignTokens.Color.semantic.textSecondary.opacity(0.05)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // 显示反馈
        showFeedback = true
        
        // 2 秒后隐藏反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showFeedback = false
        }
    }
}

// MARK: - Preview

#Preview("Message Toolbar") {
    VStack(spacing: 16) {
        MessageToolbarView(
            message: ChatMessage(role: .user, content: "Hello, this is a test message to copy."),
            isAssistantMessage: false
        )
        
        MessageToolbarView(
            message: ChatMessage(role: .assistant, content: "I can help you with coding tasks. This is a longer message content."),
            isAssistantMessage: true
        )
    }
    .padding()
    .background(Color.black)
}
