import SwiftUI

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    let message: ChatMessage
    @State private var isToolOutputExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar
            if message.role == .user {
                if message.toolCallID == nil {
                    Spacer()
                } else {
                    // 工具输出头像 (System/Tool)
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                        .clipShape(Circle())
                }
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Color.semantic.primary.opacity(0.1))
                    .clipShape(Circle())
            }

            // MARK: - Content
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    Text(String(localized: "Dev Assistant", table: "DevAssistant"))
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                } else if message.toolCallID != nil {
                    Text(String(localized: "Tool Output", table: "DevAssistant"))
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                if message.toolCallID != nil {
                    // 工具输出视图
                    DisclosureGroup(
                        isExpanded: $isToolOutputExpanded,
                        content: {
                            Text(message.content)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.top, 8)
                                .textSelection(.enabled)
                        },
                        label: {
                            HStack {
                                Text(summaryForToolOutput(message.content))
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    )
                    .padding(10)
                    .background(bubbleColor)
                    .cornerRadius(8)
                } else {
                    // 普通消息
                    Group {
                        if let attributedString = try? AttributedString(markdown: message.content) {
                            Text(attributedString)
                        } else {
                            Text(message.content)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)
                    .textSelection(.enabled)
                }
            }

            if message.role == .assistant || message.toolCallID != nil {
                Spacer()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.info)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Color.semantic.info.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Helper Methods

    /// 生成工具输出的摘要文本
    private func summaryForToolOutput(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        if lines.count > 1 {
            return String(localized: "%@ (%ld lines)...", table: "DevAssistant")
        } else {
            return content.prefix(50) + (content.count > 50 ? "..." : "")
        }
    }

    /// 气泡背景颜色
    var bubbleColor: Color {
        if message.isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        if message.toolCallID != nil {
            return DesignTokens.Color.semantic.textTertiary.opacity(0.05)
        }
        switch message.role {
        case .user: return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant: return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default: return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }

    /// 文本颜色
    var textColor: Color {
        if message.isError {
            return DesignTokens.Color.semantic.error
        }
        return DesignTokens.Color.semantic.textPrimary
    }
}

// MARK: - Preview

#Preview("User Message") {
    ChatBubble(message: ChatMessage(role: .user, content: "Hello, how can you help me?"))
        .padding()
        .background(Color.black)
}

#Preview("Assistant Message") {
    ChatBubble(message: ChatMessage(role: .assistant, content: "I can help you with coding tasks."))
        .padding()
        .background(Color.black)
}

#Preview("Tool Output") {
    ChatBubble(message: ChatMessage(role: .system, content: "File contents: \nLine 1\nLine 2\nLine 3", toolCallID: "test"))
        .padding()
        .background(Color.black)
}

#Preview("Error Message") {
    ChatBubble(message: ChatMessage(role: .assistant, content: "An error occurred", isError: true))
        .padding()
        .background(Color.black)
}
