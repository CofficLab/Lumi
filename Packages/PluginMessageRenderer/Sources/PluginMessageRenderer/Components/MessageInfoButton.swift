import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct MessageInfoButton: View {
    @LumiTheme private var theme

    let message: Message
    @State private var isPresented = false

    var body: some View {
        AppIconButton(
            systemImage: "info.circle",
            tint: isPresented ? theme.textPrimary : theme.textSecondary,
            size: .compact,
            isActive: isPresented
        ) {
            isPresented.toggle()
        }
        .help(LumiPluginLocalization.string("消息详情", bundle: .module))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            MessageInfoPopoverContent(message: message)
        }
    }
}

struct MessageInfoPopoverContent: View {
    @LumiTheme private var theme

    let message: Message

    private static let fullTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                infoSection("基本信息") {
                    infoRow("消息 ID", value: message.id.uuidString, isMono: true)
                    infoRow("会话 ID", value: message.conversationID.uuidString, isMono: true)
                    infoRow("角色", value: message.role.rawValue)
                    infoRow("创建时间", value: Self.fullTimestampFormatter.string(from: message.createdAt))
                    infoRow("渲染类型", value: displayValue(message.renderKind))
                    if let preferred = message.preferredRendererID, !preferred.isEmpty {
                        infoRow("期望渲染器", value: preferred, isMono: true)
                    }
                    if let turnID = message.turnID {
                        infoRow("轮次 ID", value: turnID.uuidString, isMono: true)
                    }
                    infoRow("错误标记", value: message.isError ? "是" : "否")
                }

                infoSection("模型") {
                    infoRow("供应商", value: displayValue(message.providerID))
                    infoRow("模型", value: displayValue(message.modelName))
                }

                if message.latencyMs != nil || message.timeToFirstTokenMs != nil || message.streamingDurationMs != nil {
                    infoSection("性能") {
                        if let latency = message.latencyMs {
                            infoRow("总耗时", value: MessageViewHelpers.formatMilliseconds(latency))
                        }
                        if let ttft = message.timeToFirstTokenMs {
                            infoRow("首 Token 延迟", value: MessageViewHelpers.formatMilliseconds(ttft))
                        }
                        if let streaming = message.streamingDurationMs {
                            infoRow("流式时长", value: MessageViewHelpers.formatMilliseconds(streaming))
                        }
                    }
                }

                if message.toolCallID != nil {
                    infoSection("工具关联") {
                        infoRow("Tool Call ID", value: displayValue(message.toolCallID), isMono: true)
                    }
                }

                let hasHttpDetail = message.httpStatusCode != nil
                    || (message.httpBody?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                if let detail = errorDetailSummary(for: message), !detail.isEmpty {
                    infoSection("错误详情") {
                        infoMultilineRow("原始错误", value: detail)
                        httpDetailRows()
                    }
                } else if hasHttpDetail {
                    infoSection("错误详情") {
                        httpDetailRows()
                    }
                }

                infoSection("内容统计") {
                    infoRow("字符数", value: "\(message.content.count)")
                    infoRow("行数", value: "\(lineCount(in: message.content))")
                    infoRow("内容为空", value: message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "是" : "否")
                    if let thinking = message.metadata["thinkingContent"], !thinking.isEmpty {
                        infoRow("思考内容", value: "\(thinking.count) 字符")
                    }
                    if message.metadata["hasImages"] == "true" {
                        infoRow("图片附件", value: "是")
                    }
                }

                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    infoSection("工具调用 (\(toolCalls.count))") {
                        ForEach(Array(toolCalls.enumerated()), id: \.offset) { index, toolCall in
                            toolCallSummary(index: index + 1, toolCall: toolCall)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 320)
        .frame(maxHeight: 460)
    }

    @ViewBuilder
    private func infoSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
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

    private func infoRow(_ label: String, value: String, isMono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: isMono ? .monospaced : .default))
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func infoMultilineRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)

            ScrollView(.vertical, showsIndicators: true) {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func toolCallSummary(index: Int, toolCall: MessageToolCall) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            infoRow("#\(index) 操作", value: toolCall.displayDescription ?? "执行工具")
            infoRow("ID", value: toolCall.id, isMono: true)
            infoRow("参数", value: "\(toolCall.arguments.count) 字符")
            infoRow("结果", value: toolCallResultSummary(toolCall))
        }
        .padding(.vertical, 4)
    }

    private func toolCallResultSummary(_ toolCall: MessageToolCall) -> String {
        guard let result = toolCall.result else {
            return "等待中"
        }

        var parts = [result.isError ? "失败" : "成功"]
        parts.append("\(result.content.count) 字符")
        if let duration = result.duration {
            parts.append(MessageViewHelpers.formatDuration(duration))
        }
        return parts.joined(separator: " · ")
    }

    private func errorDetailSummary(for message: Message) -> String? {
        ErrorTransportDetailsResolver.infoPopoverErrorSummary(for: message)
    }

    @ViewBuilder
    private func httpDetailRows() -> some View {
        if let status = message.httpStatusCode {
            infoRow("HTTP 状态码", value: "\(status)", isMono: true)
        }
        if let body = message.httpBody, !body.isEmpty {
            infoMultilineRow("HTTP 响应体", value: body)
        }
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "—"
        }
        return value
    }

    private func lineCount(in text: String) -> Int {
        max(1, text.components(separatedBy: .newlines).count)
    }
}
