import SwiftUI
import LumiCoreKit
import AgentToolKit
import LumiUI

/// 负责完整渲染一条助手消息（包含头部、思考过程、工具调用与正文）
public struct AssistantMessage: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let message: ChatMessage
    public let isLastMessage: Bool

    @Binding var showRawMessage: Bool
    @State private var showDetailPopover = false

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

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

    // MARK: - Body

    public var body: some View {
        Group {
            if message.isToolOutput {
                ToolOutputView(message: message)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if MessageRendererRuntime.showsAssistantHeaderProvider() {
                        headerSection
                    }

//                    if shouldShowThinkingProcess {
//                        ThinkingProcessView(thinkingText: thinkingText)
//                    }

                    if message.hasToolCalls {
                        MessageWithToolCallsView(
                            message: message,
                        )
                    } else {
                        MarkdownView(
                            message: message,
                            showRawMessage: showRawMessage
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
            HStack(alignment: .center, spacing: 6) {
                AvatarView.assistant
                AppIdentityRow(title: "Lumi", metadata: identityMetadata)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                // 复制按钮
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                // 用户消息才显示重发，这里是助手消息，不需要重发按钮

                // 时间戳
                Text(formatTimestamp(message.timestamp))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)

                // 消息详情按钮
                MessageDetailButton(
                    message: message,
                    showDetailPopover: $showDetailPopover,
                    formatTimestamp: formatTimestamp,
                    formatModelName: formatModelName,
                    formatCount: formatCount,
                    formatMilliseconds: formatMilliseconds,
                    formatNumber: formatNumber
                )

                // 切换原始消息按钮
                // RawMessageToggleButton(showRawMessage: $showRawMessage)
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

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatMilliseconds(_ milliseconds: Double) -> String {
        if milliseconds < 1_000 {
            return "\(Int(milliseconds.rounded()))ms"
        }
        if milliseconds < 60_000 {
            return String(format: "%.1fs", milliseconds / 1_000)
        }
        let totalSeconds = Int((milliseconds / 1_000).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)m\(seconds)s"
    }

    private func formatNumber(_ value: Double) -> String {
        String(format: "%.2g", value)
    }
}
