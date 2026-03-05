import SwiftUI
import Textual

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    let message: ChatMessage
    @State private var showRawMessage: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar

            AvatarChatView(role: message.role, isToolOutput: message.toolCallID != nil)

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
                        toolType: inferToolType(from: message)
                    )
                } else if message.role == .assistant && hasToolCalls {
                    AssistantMessageWithToolCallsView(message: message)
                } else {
                    MarkdownMessageView(message: message, showRawMessage: showRawMessage)
                        .messageBubbleStyle(role: message.role, isError: message.isError)
                        .overlay(alignment: .topTrailing) {
                            if message.role == .assistant {
                                RawMessageToggleButton(showRawMessage: $showRawMessage)
                            }
                        }
                }
            }

            Spacer()
        }
    }

    // MARK: - Helper Properties

    /// 检查消息是否包含工具调用
    private var hasToolCalls: Bool {
        message.toolCalls != nil && !message.toolCalls!.isEmpty
    }

    // MARK: - Infer Tool Type from Tool Call ID

    private func inferToolType(from message: ChatMessage) -> ToolOutputView.ToolType? {
        // 根据 toolCallID 查找对应的工具调用
        // 由于消息之间没有直接关联，我们通过工具名称前缀来推断
        // 这是一个简化实现，更好的方式是在消息间建立关联
        return .unknown
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

extension View {
    /// 应用消息气泡样式
    func messageBubbleStyle(role: MessageRole, isError: Bool) -> some View {
        self
            .font(DesignTokens.Typography.code)
            .padding(10)
            .padding(.trailing, role == .assistant ? 20 : 0)
            .background(bubbleBackgroundColor(role: role, isError: isError))
            .foregroundColor(textColor(isError: isError))
            .cornerRadius(12)
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

#Preview("Assistant with Tool Calls") {
    let toolCalls = [
        ToolCall(id: "tool_1", name: "read_file", arguments: "{\"path\": \"/Users/angel/Code/Lumi/App.swift\"}"),
        ToolCall(id: "tool_2", name: "run_command", arguments: "{\"command\": \"ls -la\"}")
    ]
    let message = ChatMessage(
        role: .assistant,
        content: "让我帮你查看项目结构和文件内容。",
        toolCalls: toolCalls
    )

    return AssistantMessageWithToolCallsView(message: message)
        .padding()
        .frame(width: 600)
        .background(Color.black)
}

#Preview("Assistant with Tool Calls (No Text)") {
    let toolCalls = [
        ToolCall(id: "tool_1", name: "list_directory", arguments: "{\"path\": \"/Users/angel/Code/Lumi\"}")
    ]
    let message = ChatMessage(
        role: .assistant,
        content: "",
        toolCalls: toolCalls
    )

    return AssistantMessageWithToolCallsView(message: message)
        .padding()
        .frame(width: 600)
        .background(Color.black)
}

#Preview("Multiple Messages") {
    VStack(alignment: .leading, spacing: 12) {
        ChatBubble(message: ChatMessage(role: .user, content: "List all files in the project"))

        let toolCalls = [
            ToolCall(id: "tool_1", name: "list_directory", arguments: "{\"path\": \"/Users/angel/Code/Lumi\"}")
        ]
        AssistantMessageWithToolCallsView(message: ChatMessage(role: .assistant, content: "我来列出项目中的所有文件。", toolCalls: toolCalls))

        ChatBubble(message: ChatMessage(role: .system, content: "Project files: 142", toolCallID: "test"))
    }
    .padding()
    .frame(width: 500)
    .background(Color.black)
}
