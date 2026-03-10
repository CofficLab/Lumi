import SwiftUI
import OSLog
import MagicKit

// MARK: - Chat Bubble

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🫧"
    /// 是否启用详细日志
    nonisolated static let verbose = true

    /// 消息对象
    let message: ChatMessage
    /// 是否是最后一条消息
    let isLastMessage: Bool
    /// 与当前 assistant 工具调用关联的工具输出（仅用于 UI 分组展示）
    let relatedToolOutputs: [ChatMessage]

    @ObservedObject private var expansionState = MessageExpansionState.shared
    @State private var showRawMessage: Bool = false

    /// 智能体提供者（用于获取思考状态）
    @EnvironmentObject var agentProvider: AgentProvider
    /// 思考状态 ViewModel
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateViewModel
    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    /// 初始化
    /// - Parameters:
    ///   - message: 消息对象
    ///   - isLastMessage: 是否是最后一条消息
    ///   - relatedToolOutputs: 关联的工具输出
    init(message: ChatMessage, isLastMessage: Bool, relatedToolOutputs: [ChatMessage] = []) {
        self.message = message
        self.isLastMessage = isLastMessage
        self.relatedToolOutputs = relatedToolOutputs
    }

    // MARK: - Computed Properties

    /// 判断是否是长消息
    private var isLongMessage: Bool {
        let charCount = message.content.count
        let lineCount = message.content.components(separatedBy: "\n").count
        return charCount > 1000 || lineCount > 50
    }

    /// 当前消息的展开状态
    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id)
    }

    /// 是否是当前正在流式传输的消息
    private var isCurrentStreamingMessage: Bool {
        agentProvider.currentStreamingMessageId == message.id
    }

    /// 是否应该显示思考过程
    private var shouldShowThinkingProcess: Bool {
        // 必须是助手消息
        guard message.role == .assistant else { return false }
        // 如果有存储的思考内容，显示它
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return true
        }
        // 否则：只要有实时思考文本就展示（绑定到当前流式消息，避免所有历史消息一起显示）
        return isCurrentStreamingMessage && !thinkingStateViewModel.thinkingText.isEmpty
    }

    /// 获取思考过程文本（优先使用存储的，否则使用实时的）
    private var thinkingText: String {
        // 如果有存储的思考内容，使用它
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return storedThinking
        }
        // 否则使用实时的思考文本
        return thinkingStateViewModel.thinkingText
    }

    /// 是否正在思考（用于动画）
    private var isThinking: Bool {
        // 如果有存储的思考内容，说明思考已完成
        if message.thinkingContent != nil {
            return false
        }
        // 否则仅对当前流式消息展示实时思考动画
        return isCurrentStreamingMessage && thinkingStateViewModel.isThinking
    }

    /// 检查消息是否包含工具调用
    private var hasToolCalls: Bool {
        message.toolCalls != nil && !message.toolCalls!.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar

            AvatarChatView(role: message.role, isToolOutput: message.toolCallID != nil)

            // MARK: - Content

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    // 助手消息：显示 Header（包含供应商、模型信息和响应时间）
                    VStack(alignment: .leading, spacing: 4) {
                        AssistantMessageHeader(
                            message: message,
                            showRawMessage: $showRawMessage,
                            isExpanded: isExpanded,
                            onToggleExpand: {
                                Task { @MainActor in
                                    expansionState.toggleExpansion(id: message.id)
                                }
                            },
                            isLongMessage: isLongMessage,
                            isLastMessage: isLastMessage
                        )

                        // 思考过程展示（对最后一条助手消息显示）
                        if shouldShowThinkingProcess {
                            ThinkingProcessView(
                                thinkingText: thinkingText,
                                isThinking: isThinking
                            )
                        }

                        if hasToolCalls {
                            AssistantMessageWithToolCallsView(
                                message: message,
                                toolOutputMessages: relatedToolOutputs
                            )
                        } else {
                            MarkdownMessageView(
                                message: message,
                                showRawMessage: showRawMessage,
                                isCollapsible: isLongMessage,
                                isExpanded: isExpanded,
                                onToggleExpand: {
                                    Task { @MainActor in
                                        expansionState.toggleExpansion(id: message.id)
                                    }
                                }
                            )
                            .messageBubbleStyle(role: message.role, isError: message.isError)
                        }

                        // 消息工具栏（底部按钮行）
                        MessageToolbarView(
                            message: message,
                            isAssistantMessage: true
                        )
                    }
                } else if message.toolCallID != nil {
                    // 工具输出
                    RoleLabel.tool
                    ToolOutputView(
                        message: message,
                        toolType: inferToolType(from: message)
                    )
                    // 工具输出也显示工具栏
                    MessageToolbarView(
                        message: message,
                        isAssistantMessage: false
                    )
                } else {
                    // 用户消息
                    VStack(alignment: .leading, spacing: 4) {
                        MarkdownMessageView(
                            message: message,
                            showRawMessage: showRawMessage,
                            isCollapsible: false,
                            isExpanded: true,
                            onToggleExpand: {}
                        )
                        .messageBubbleStyle(role: message.role, isError: message.isError)

                        // 消息工具栏（底部按钮行）
                        MessageToolbarView(
                            message: message,
                            isAssistantMessage: false
                        )
                    }
                }
            }

            Spacer()
        }
    }

    /// 根据工具调用 ID 推断工具类型
    /// - Parameter message: 消息对象
    /// - Returns: 工具类型
    private func inferToolType(from message: ChatMessage) -> ToolOutputView.ToolType? {
        // 根据 toolCallID 查找对应的工具调用
        // 由于消息之间没有直接关联，我们通过工具名称前缀来推断
        // 这是一个简化实现，更好的方式是在消息间建立关联
        return .unknown
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
