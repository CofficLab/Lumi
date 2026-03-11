import MagicKit
import OSLog
import SwiftUI

// MARK: - Assistant Message Header

/// 助手消息头部组件
/// 显示供应商、模型信息、性能指标和控制按钮
struct AssistantMessageHeader: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📋"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 消息对象
    let message: ChatMessage
    /// 原始消息显示状态绑定
    @Binding var showRawMessage: Bool
    /// 是否已展开
    let isExpanded: Bool
    /// 切换展开/折叠回调
    let onToggleExpand: () -> Void
    /// 是否是长消息
    let isLongMessage: Bool
    /// 是否为最后一条消息（用于实时状态展示）
    let isLastMessage: Bool

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider
    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel
    /// 思考状态 ViewModel
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 供应商和模型信息
            HStack(alignment: .center, spacing: 4) {
                Text("Lumi")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                // 供应商名称（如果有）
                if let providerId = message.providerId {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(formatProviderName(providerId))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                // 模型名称（如果有）
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
                performanceMetricsGroup

                // 折叠/展开按钮（仅当内容是长消息时显示）
                if isLongMessage {
                    expandCollapseButton
                }

                // 切换源码/渲染按钮
                markdownRenderingToggleButton

                // 切换原始消息按钮
                rawMessageToggleButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Computed Properties

    /// 性能指标组
    private var performanceMetricsGroup: some View {
        HStack(alignment: .center, spacing: 8) {
            // 耗时进度条（如果有 TTFT 和总耗时）
            if let ttft = message.timeToFirstToken, let latency = message.latency {
                LatencyProgressBar(ttft: ttft, totalLatency: latency)
            }

            // Token 统计（如果有）
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

            // 完成原因（如果有）
            if let finishReason = message.finishReason {
                HStack(alignment: .center, spacing: 2) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8, weight: .medium))
                    Text(formatFinishReason(finishReason))
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
    }

    /// 展开/折叠按钮
    private var expandCollapseButton: some View {
        Group {
            if isExpanded {
                CollapseButton(action: onToggleExpand)
            } else {
                Text("已折叠")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
            }
        }
    }

    /// Markdown 渲染切换按钮
    private var markdownRenderingToggleButton: some View {
        MarkdownRenderingToggleButton()
    }

    /// 原始消息切换按钮
    private var rawMessageToggleButton: some View {
        RawMessageToggleButton(showRawMessage: $showRawMessage)
    }

    // MARK: - Helper Methods

    /// 格式化供应商名称（显示友好名称）
    /// - Parameter providerId: 供应商标识
    /// - Returns: 友好的供应商名称
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

    /// 格式化模型名称（简化显示）
    /// - Parameter name: 模型名称
    /// - Returns: 简化后的模型名称
    private func formatModelName(_ name: String) -> String {
        // 移除日期后缀，例如：claude-sonnet-4-20250514 → claude-sonnet-4
        // gpt-4o-2024-11-20 → gpt-4o
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }

    /// 格式化响应时间
    /// - Parameter latency: 响应时间（毫秒）
    /// - Returns: 格式化后的响应时间字符串
    private func formatLatency(_ latency: Double) -> String {
        if latency < 1000 {
            return String(format: "%.0fms", latency)
        } else {
            return String(format: "%.1fs", latency / 1000.0)
        }
    }

    /// 格式化完成原因
    /// - Parameter reason: 完成原因
    /// - Returns: 格式化后的完成原因字符串
    private func formatFinishReason(_ reason: String) -> String {
        let reasonMap: [String: String] = [
            "stop": "完成",
            "length": "长度限制",
            "content_filter": "内容过滤",
            "tool_calls": "工具调用",
            "max_tokens": "最大 Token",
            "temperature": "温度",
        ]
        return reasonMap[reason] ?? reason
    }
}
