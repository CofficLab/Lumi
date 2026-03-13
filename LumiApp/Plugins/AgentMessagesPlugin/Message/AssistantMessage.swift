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

    // MARK: - Computed

    private var isLongMessage: Bool {
        let charCount = message.content.count
        let lineCount = message.content.components(separatedBy: "\n").count
        return charCount > 1000 || lineCount > 50
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id)
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
        HStack(alignment: .center, spacing: 8) {
            // 左侧：供应商和模型信息
            HStack(alignment: .center, spacing: 4) {
                Text("Lumi")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                if let providerId = message.providerId {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(formatProviderName(providerId))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                if let modelName = message.modelName {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(formatModelName(modelName))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                // 性能指标组
//                performanceMetricsGroup

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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
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
                        expansionState.toggleExpansion(id: message.id)
                    }
                })
            } else {
                Text("已折叠")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
            }
        }
    }

    // MARK: - Helper Methods (Header)

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    private func formatProviderName(_ providerId: String) -> String {
        let providerNames: [String: String] = [
            "anthropic": "Anthropic",
            "openai": "OpenAI",
            "zhipu": "智谱 AI",
            "deepseek": "深度求索",
            "aliyun": "阿里云",
            "azure": "Azure",
            "google": "Google",
            "mistral": "Mistral",
            "groq": "Groq",
            "ollama": "Ollama",
        ]
        return providerNames[providerId] ?? providerId.capitalized
    }

    private func formatModelName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }
}

