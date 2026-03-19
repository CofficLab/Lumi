import SwiftUI

// MARK: - Chat Bubble

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    /// 消息对象
    let message: ChatMessage
    /// 是否是最后一条消息
    let isLastMessage: Bool
    /// 与当前 assistant 工具调用关联的工具输出（仅用于 UI 分组展示）
    let relatedToolOutputs: [ChatMessage]
    /// 是否为当前正在流式生成的 assistant 消息
    let isStreaming: Bool

    @State private var showRawMessage: Bool = false

    /// 初始化
    /// - Parameters:
    ///   - message: 消息对象
    ///   - isLastMessage: 是否是最后一条消息
    ///   - relatedToolOutputs: 关联的工具输出
    init(
        message: ChatMessage,
        isLastMessage: Bool,
        relatedToolOutputs: [ChatMessage] = [],
        isStreaming: Bool = false
    ) {
        self.message = message
        self.isLastMessage = isLastMessage
        self.relatedToolOutputs = relatedToolOutputs
        self.isStreaming = isStreaming
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar

            AvatarChatView(role: message.role, isToolOutput: message.isToolOutput)

            // MARK: - Content

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    if isStreaming {
                        StreamingAssistantRowView(message: message)
                            .messageBubbleStyle(role: message.role, isError: message.isError)
                    } else {
                        AssistantMessage(
                            message: message,
                            isLastMessage: isLastMessage,
                            relatedToolOutputs: relatedToolOutputs,
                            showRawMessage: $showRawMessage
                        )
                    }
                } else if message.role == .tool || message.isToolOutput {
                    ToolOutputView(message: message)
                } else {
                    // 用户/系统/状态消息
                    VStack(alignment: .leading, spacing: 4) {
                        switch message.role {
                        case .user:
                            UserMessage(
                                message: message,
                                showRawMessage: $showRawMessage
                            )
                        case .system:
                            SystemMessage(
                                message: message,
                                showRawMessage: $showRawMessage
                            )
                        case .status:
                            StatusMessage(
                                message: message
                            )
                        case .tool:
                            ToolOutputView(message: message)
                        default:
                            MarkdownView(
                                message: message,
                                showRawMessage: showRawMessage,
                                isCollapsible: false,
                                isExpanded: true,
                                onToggleExpand: {}
                            )
                            .messageBubbleStyle(role: message.role, isError: message.isError)
                        }
                    }
                }

            }

            Spacer()
        }
    }

}

// MARK: - Preview

#Preview("User Message") {
    ChatBubble(
        message: ChatMessage(role: .user, content: "Hello, how can you help me?"),
        isLastMessage: false
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message with Latency") {
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: "I can help you with coding tasks.",
            providerId: "anthropic",
            modelName: "claude-sonnet-4-20250514",
            latency: 1234.56,
            inputTokens: 100,
            outputTokens: 200,
            totalTokens: 300,
            timeToFirstToken: 234.5
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message (OpenAI)") {
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: "I can help you with coding tasks.",
            providerId: "openai",
            modelName: "gpt-4o",
            latency: 456.78,
            inputTokens: 50,
            outputTokens: 150,
            totalTokens: 200,
            timeToFirstToken: 123.4
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Assistant Message (Long Content)") {
    let longContent = String(repeating: "这是一段测试文字，用于验证长消息的折叠功能。", count: 100)
    ChatBubble(
        message: ChatMessage(
            role: .assistant,
            content: longContent,
            providerId: "anthropic",
            modelName: "claude-sonnet-4-20250514",
            latency: 2345.67
        ),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}

#Preview("Tool Output") {
    ChatBubble(
        message: ChatMessage(role: .system, content: "File contents: \nLine 1\nLine 2\nLine 3", toolCallID: "test"),
        isLastMessage: false
    )
    .padding()
    .background(Color.black)
}

#Preview("Error Message") {
    ChatBubble(
        message: ChatMessage(role: .assistant, content: "An error occurred", isError: true),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}
