import SwiftUI
import Textual

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    let message: ChatMessage
    @State private var isToolOutputExpanded: Bool = false
    @State private var showRawMessage: Bool = false

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
                        if showRawMessage {
                            Text(message.content)
                        } else {
                            // 使用 Textual 渲染 Markdown 内容
                            if message.role == .user {
                                // 用户消息：使用 InlineText
                                InlineText(markdown: message.content)
                            } else {
                                // 助手消息：使用 StructuredText 支持完整 Markdown
                                StructuredText(markdown: message.content)
                                    .textual.structuredTextStyle(.gitHub)
                            }
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .padding(.trailing, message.role == .assistant ? 20 : 0) // 为按钮预留空间
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)
                    .textual.textSelection(.enabled)
                    .overlay(alignment: .topTrailing) {
                        if message.role == .assistant {
                            Button(action: { showRawMessage.toggle() }) {
                                Image(systemName: showRawMessage ? "text.bubble.fill" : "curlybraces")
                                    .font(.system(size: 10))
                                    .foregroundColor(textColor.opacity(0.6))
                                    .padding(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding([.top, .trailing], 2)
                        }
                    }
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

    /// 预处理 Markdown 内容，优化显示效果
    private func preprocessMarkdown(_ content: String) -> String {
        // 1. 标准化换行符
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
                                .replacingOccurrences(of: "\r", with: "\n")

        // 2. 保护代码块：通过 ``` 分割
        // 偶数索引部分是普通文本，奇数索引部分是代码块
        var parts = normalized.components(separatedBy: "```")

        for i in stride(from: 0, to: parts.count, by: 2) {
            var text = parts[i]

            // 3. 确保列表和标题前有双换行，从而正确分段
            // 查找前面不是换行符的 标题、列表标记
            text = text.replacingOccurrences(
                of: "([^\\n])\\n(#{1,6}\\s|[-*+]\\s|\\d+\\.\\s)",
                with: "$1\n\n$2",
                options: .regularExpression
            )

            // 4. 将剩余的单换行转换为 Markdown 硬换行 (两个空格 + 换行)
            // 排除连在一起的换行符（即保留段落间距）
            text = text.replacingOccurrences(
                of: "(?<!\\n)\\n(?!\\n)",
                with: "  \n",
                options: .regularExpression
            )

            parts[i] = text
        }

        return parts.joined(separator: "```")
    }

    /// 生成工具输出的摘要文本
    private func summaryForToolOutput(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        if lines.count > 1 {
            let firstLine = String(lines.first?.prefix(50) ?? "")
            let format = String(localized: "%@ (%ld lines)...", table: "DevAssistant")
            return String(format: format, firstLine, lines.count)
        } else {
            return String(content.prefix(50)) + (content.count > 50 ? "..." : "")
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
