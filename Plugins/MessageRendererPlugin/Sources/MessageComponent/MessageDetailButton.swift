import SwiftUI
import LumiCoreKit
import LumiUI

/// 消息详情按钮，点击后以 Popover 展示消息的完整属性信息。
///
/// 位于 assistant 消息 header 的 trailing 区域，与复制按钮、时间戳并列。
struct MessageDetailButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference

    let message: ChatMessage
    @Binding var showDetailPopover: Bool

    let formatTimestamp: (Date) -> String
    let formatModelName: (String) -> String
    let formatCount: (Int) -> String
    let formatMilliseconds: (Double) -> String
    let formatNumber: (Double) -> String

    @State private var isHovered = false

    var body: some View {
        Button(action: { showDetailPopover.toggle() }) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textSecondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? theme.textSecondary.opacity(0.08) : theme.textSecondary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help("消息详情")
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $showDetailPopover, arrowEdge: .bottom) {
            MessageDetailPopoverContent(
                message: message,
                formatTimestamp: formatTimestamp,
                formatModelName: formatModelName,
                formatCount: formatCount,
                formatMilliseconds: formatMilliseconds,
                formatNumber: formatNumber
            )
        }
    }
}

/// 消息详情 Popover 内容视图
///
/// 以分组表格形式展示消息的所有属性，包括基本信息、模型信息、Token 使用量、
/// 性能指标和请求参数等。
struct MessageDetailPopoverContent: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let message: ChatMessage
    let formatTimestamp: (Date) -> String
    let formatModelName: (String) -> String
    let formatCount: (Int) -> String
    let formatMilliseconds: (Double) -> String
    let formatNumber: (Double) -> String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 基本信息
                detailSection("基本信息") {
                    detailRow("消息 ID", value: message.id.uuidString)
                    detailRow("会话 ID", value: message.conversationId.uuidString)
                    detailRow("时间", value: formatTimestamp(message.timestamp))
                    if let finishReason = message.finishReason, !finishReason.isEmpty {
                        detailRow("完成原因", value: finishReason)
                    }
                }

                // 模型信息
                if message.providerId != nil || message.modelName != nil {
                    detailSection("模型信息") {
                        if let providerId = message.providerId, !providerId.isEmpty {
                            detailRow("供应商", value: providerId)
                        }
                        if let modelName = message.modelName, !modelName.isEmpty {
                            detailRow("模型", value: modelName)
                            detailRow("显示名称", value: formatModelName(modelName))
                        }
                    }
                }

                // Token 使用量
                if message.inputTokens != nil || message.outputTokens != nil || message.totalTokens != nil {
                    detailSection("Token 使用量") {
                        if let inputTokens = message.inputTokens {
                            detailRow("输入", value: formatCount(inputTokens))
                        }
                        if let outputTokens = message.outputTokens {
                            detailRow("输出", value: formatCount(outputTokens))
                        }
                        if let totalTokens = message.totalTokens {
                            detailRow("总计", value: formatCount(totalTokens))
                        }
                    }
                }

                // 性能指标
                if message.latency != nil || message.timeToFirstToken != nil
                    || message.streamingDuration != nil || message.thinkingDuration != nil {
                    detailSection("性能指标") {
                        if let latency = message.latency {
                            detailRow("请求延迟", value: formatMilliseconds(latency))
                        }
                        if let timeToFirstToken = message.timeToFirstToken {
                            detailRow("首 Token 延迟 (TTFT)", value: formatMilliseconds(timeToFirstToken))
                        }
                        if let streamingDuration = message.streamingDuration {
                            detailRow("流式传输", value: formatMilliseconds(streamingDuration))
                        }
                        if let thinkingDuration = message.thinkingDuration {
                            detailRow("思考耗时", value: formatMilliseconds(thinkingDuration))
                        }
                    }
                }

                // 生成参数
                if message.temperature != nil || message.maxTokens != nil {
                    detailSection("生成参数") {
                        if let temperature = message.temperature {
                            detailRow("Temperature", value: formatNumber(temperature))
                        }
                        if let maxTokens = message.maxTokens {
                            detailRow("Max Tokens", value: formatCount(maxTokens))
                        }
                    }
                }

                // 请求追踪
                if let requestId = message.requestId, !requestId.isEmpty {
                    detailSection("请求追踪") {
                        detailRow("Request ID", value: requestId, isMono: true)
                    }
                }

                // 内容统计
                detailSection("内容统计") {
                    detailRow("字符数", value: "\(message.content.count)")
                    detailRow("工具调用", value: message.toolCalls?.count.description ?? "0")
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .frame(maxHeight: 400)
    }

    // MARK: - Subviews

    private func detailSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 2) {
                content()
            }
        }
    }

    private func detailRow(_ label: String, value: String, isMono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: isMono ? .monospaced : .default))
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
