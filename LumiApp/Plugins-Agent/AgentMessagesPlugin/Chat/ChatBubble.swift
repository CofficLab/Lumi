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
