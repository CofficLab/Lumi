import MagicKit
import OSLog
import SwiftUI

// MARK: - AppKit Chat Bubble

/// AppKit 插件内的聊天气泡（复制自 ChatBubble 并改名）
struct AppKitChatBubble: View, SuperLog {
    nonisolated static let emoji = "🫧"
    nonisolated static let verbose = true

    let message: ChatMessage
    let isLastMessage: Bool
    let relatedToolOutputs: [ChatMessage]

    @ObservedObject private var expansionState = MessageExpansionState.shared
    @State private var showRawMessage: Bool = false
    @State private var isHovered: Bool = false

    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    init(message: ChatMessage, isLastMessage: Bool, relatedToolOutputs: [ChatMessage] = []) {
        self.message = message
        self.isLastMessage = isLastMessage
        self.relatedToolOutputs = relatedToolOutputs
    }

    private var isLongMessage: Bool {
        let charCount = message.content.count
        let lineCount = message.content.components(separatedBy: "\n").count
        return charCount > 1000 || lineCount > 50
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id)
    }

    private var isCurrentStreamingMessage: Bool {
        agentProvider.currentStreamingMessageId == message.id
    }

    private var shouldShowThinkingProcess: Bool {
        guard message.role == .assistant else { return false }
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return true
        }
        return isCurrentStreamingMessage && !thinkingStateViewModel.thinkingText.isEmpty
    }

    private var thinkingText: String {
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return storedThinking
        }
        return thinkingStateViewModel.thinkingText
    }

    private var isThinking: Bool {
        if message.thinkingContent != nil {
            return false
        }
        return isCurrentStreamingMessage && thinkingStateViewModel.isThinking
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarChatView(role: message.role, isToolOutput: message.isToolOutput)

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    AssistantMessage(
                        message: message,
                        isLastMessage: isLastMessage,
                        relatedToolOutputs: relatedToolOutputs,
                        showRawMessage: $showRawMessage
                    )
                } else {
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
                                message: message,
                                showRawMessage: $showRawMessage
                            )
                        default:
                            MarkdownMessageView(
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

                let shouldShowToolbar =
                    message.shouldShowToolbar &&
                    !message.isToolOutput &&
                    !(message.role == .assistant && message.hasToolCalls)

                if shouldShowToolbar {
                    MessageToolbarView(
                        message: message,
                        isAssistantMessage: message.role == .assistant
                    )
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                }
            }

            Spacer()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

}

