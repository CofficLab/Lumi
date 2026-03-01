import SwiftUI
import Textual

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    let message: ChatMessage
    @State private var showRawMessage: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar

            if message.role == .user {
                if message.toolCallID == nil {
                    Spacer()
                } else {
                    // 工具输出头像 (System/Tool)
                    AvatarView.tool
                }
            } else {
                AvatarView.assistant
            }

            // MARK: - Content

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    RoleLabel.assistant
                } else if message.toolCallID != nil {
                    RoleLabel.tool
                }

                if message.toolCallID != nil {
                    ToolOutputView(
                        message: message,
                        toolType: message.toolType
                    )
                } else {
                    // 普通消息
                    MarkdownMessageView(message: message, showRawMessage: showRawMessage)
                        .messageBubbleStyle(role: message.role, isError: message.isError)
                        .overlay(alignment: .topTrailing) {
                            if message.role == .assistant {
                                RawMessageToggleButton(showRawMessage: $showRawMessage)
                            }
                        }
                }
            }

            if message.role == .assistant || message.toolCallID != nil {
                Spacer()
            } else {
                AvatarView.user
            }
        }
    }
}

// MARK: - Avatar Views

/// 头像视图
enum AvatarView {
    /// 助手头像
    static var assistant: some View {
        Image(systemName: "cpu")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.primary)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.primary.opacity(0.1))
            .clipShape(Circle())
    }

    /// 用户头像
    static var user: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.info)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.info.opacity(0.1))
            .clipShape(Circle())
    }

    /// 工具头像
    static var tool: some View {
        Image(systemName: "gearshape.2.fill")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
            .clipShape(Circle())
    }
}

// MARK: - Role Labels

/// 角色标签
enum RoleLabel {
    /// 助手标签
    static var assistant: some View {
        Text(String(localized: "Dev Assistant", table: "DevAssistant"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }

    /// 工具标签
    static var tool: some View {
        Text(String(localized: "Tool Output", table: "DevAssistant"))
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }
}

// MARK: - Raw Message Toggle Button

/// 原始消息切换按钮
struct RawMessageToggleButton: View {
    @Binding var showRawMessage: Bool

    var body: some View {
        Button(action: { showRawMessage.toggle() }) {
            Image(systemName: showRawMessage ? "text.bubble.fill" : "curlybraces")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding([.top, .trailing], 2)
    }
}

// MARK: - View Modifiers

private extension View {
    /// 应用消息气泡样式
    func messageBubbleStyle(role: MessageRole, isError: Bool) -> some View {
        self
            .font(DesignTokens.Typography.code)
            .padding(10)
            .padding(.trailing, role == .assistant ? 20 : 0)
            .background(bubbleBackgroundColor(role: role, isError: isError))
            .foregroundColor(textColor(isError: isError))
            .cornerRadius(12)
            // .textual.textSelection(.enabled) - Temporarily disabled to fix "AnyTextLayoutCollection" warning
    }

    /// 气泡背景颜色
    func bubbleBackgroundColor(role: MessageRole, isError: Bool) -> Color {
        if isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        switch role {
        case .user:
            return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }

    /// 文本颜色
    func textColor(isError: Bool) -> Color {
        if isError {
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

#Preview("Multiple Messages") {
    VStack(alignment: .leading, spacing: 12) {
        ChatBubble(message: ChatMessage(role: .user, content: "List all files in the project"))
        ChatBubble(message: ChatMessage(role: .assistant, content: "I'll list all files in the project."))
        ChatBubble(message: ChatMessage(role: .system, content: "Project files: 142", toolCallID: "test"))
    }
    .padding()
    .frame(width: 500)
    .background(Color.black)
}

#Preview("Enhanced Tool Output") {
    let toolCall = ToolCall(id: "test", name: "list_directory", arguments: "{}")
    let message = ChatMessage(
        role: .system,
        content: """
        Project Structure:
        ├── LumiApp/
        ├── LumiFinder/
        └── NettoExtension/
        """,
        toolCalls: [toolCall],
        toolCallID: "test"
    )

    return ChatBubble(message: message)
        .padding()
        .frame(width: 600)
        .background(Color.black)
}
