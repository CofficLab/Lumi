import MagicKit
import OSLog
import SwiftUI

// MARK: - Assistant Message
//
/// 负责完整渲染一条助手消息（包含头部、思考过程、工具调用与正文）
struct AssistantMessage: View, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    let message: ChatMessage
    let isLastMessage: Bool
    let relatedToolOutputs: [ChatMessage]

    @ObservedObject private var expansionState = MessageExpansionState.shared
    @Binding var showRawMessage: Bool

    /// 智能体提供者（用于获取思考状态）
    @EnvironmentObject var agentProvider: AgentProvider
    /// 思考状态 ViewModel
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateViewModel

    // MARK: - Computed

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
        // 只对助手消息生效
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

    // MARK: - Body

    var body: some View {
        Group {
            if message.isToolOutput {
                // 助手角色下的工具输出消息：使用工具视图渲染
                VStack(alignment: .leading, spacing: 4) {
                    RoleLabel.tool
                    ToolOutputView(
                        message: message,
                        toolType: .unknown
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    headerSection

                    if shouldShowThinkingProcess {
                        ThinkingProcessView(
                            thinkingText: thinkingText,
                            isThinking: isThinking
                        )
                    }

                    if message.hasToolCalls {
                        MessageWithToolCallsView(
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
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
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
    }
}

