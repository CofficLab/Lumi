import MagicKit
import SwiftUI

// MARK: - Assistant Message
//
/// 负责完整渲染一条助手消息（包含头部、思考过程、工具调用与正文）
struct AssistantMessage: View {
    let message: ChatMessage
    let isLastMessage: Bool
    let relatedToolOutputs: [ChatMessage]

    @ObservedObject private var expansionState = MessageExpansionState.shared
    @Binding var showRawMessage: Bool
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private var renderMetadata: MessageRenderMetadata {
        MessageRenderCache.shared.metadata(for: message)
    }

    // MARK: - Computed

    private var isLongMessage: Bool {
        renderMetadata.isLongMessage
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id, defaultExpanded: !renderMetadata.shouldDefaultCollapse)
    }

    private var shouldShowThinkingProcess: Bool {
        if let storedThinking = message.thinkingContent {
            return !storedThinking.isEmpty
        }
        return false
    }

    private var thinkingText: String {
        if let storedThinking = message.thinkingContent, !storedThinking.isEmpty {
            return storedThinking
        }
        return ""
    }

    private var isThinking: Bool {
        false
    }

    // MARK: - Body

    var body: some View {
        Group {
            if message.isToolOutput {
                // 助手角色下的工具输出消息：使用工具视图渲染
                VStack(alignment: .leading, spacing: 4) {
                    RoleLabel.tool
                    ToolOutputView(message: message)
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
                        MarkdownView(
                            message: message,
                            showRawMessage: showRawMessage,
                            isCollapsible: isLongMessage,
                            isExpanded: isExpanded,
                            onToggleExpand: {
                                Task { @MainActor in
                                    expansionState.toggleExpansion(
                                        id: message.id,
                                        defaultExpanded: !renderMetadata.shouldDefaultCollapse
                                    )
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
        MessageHeaderView {
            AppIdentityRow(title: "Lumi", metadata: identityMetadata)
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                // 性能指标组（暂时隐藏）
//                performanceMetricsGroup

                // 复制按钮
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                // 用户消息才显示重发，这里是助手消息，不需要重发按钮

                // 折叠/展开按钮（仅当内容是长消息时显示）
                if isLongMessage {
                    expandCollapseButton
                }

                // 时间戳
                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                // 切换原始消息按钮
                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private var identityMetadata: [String] {
        var items: [String] = []
        if let providerId = message.providerId, !providerId.isEmpty {
            items.append(providerId)
        }
        if let modelName = message.modelName, !modelName.isEmpty {
            items.append(formatModelName(modelName))
        }
        return items
    }

    private var performanceMetricsGroup: some View {
        HStack(alignment: .center, spacing: 8) {
            if let ttft = message.timeToFirstToken, let latency = message.latency {
                LatencyProgressBar(ttft: ttft, totalLatency: latency)
            }

            if let inputTokens = message.inputTokens, let outputTokens = message.outputTokens {
                TokenProgressBar(inputTokens: inputTokens, outputTokens: outputTokens)
            } else if let totalTokens = message.totalTokens {
                HStack(alignment: .center, spacing: 2) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 8, weight: .medium))
                    Text("\(totalTokens)")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
    }

    private var expandCollapseButton: some View {
        Group {
            if isExpanded {
                CollapseButton(action: {
                    Task { @MainActor in
                        expansionState.toggleExpansion(
                            id: message.id,
                            defaultExpanded: !renderMetadata.shouldDefaultCollapse
                        )
                    }
                })
            } else {
                AppTag("已折叠")
            }
        }
    }

    // MARK: - Helper Methods (Header)

    private func formatTimestamp(_ date: Date) -> String {
        Self.timestampFormatter.string(from: date)
    }

    private func formatModelName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }
}
