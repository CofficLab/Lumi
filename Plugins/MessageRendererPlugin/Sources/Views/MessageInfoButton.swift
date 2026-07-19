import LumiKernel
import LumiUI
import SwiftUI

struct MessageInfoButton: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @State private var isPresented = false

    var body: some View {
        AppIconButton(
            systemImage: "info.circle",
            tint: isPresented ? theme.textPrimary : theme.textSecondary,
            size: .regular,
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

    let message: LumiChatMessage

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
                    infoRow("错误标记", value: message.isError ? "是" : "否")
                }

                infoSection("模型") {
                    infoRow("供应商", value: displayValue(message.providerID))
                    infoRow("模型", value: displayValue(message.modelName))
                }

                if message.toolCallID != nil {
                    infoSection("工具关联") {
                        infoRow("Tool Call ID", value: displayValue(message.toolCallID), isMono: true)
                    }
                }

                if let detail = errorDetailSummary(for: message), !detail.isEmpty {
                    infoSection("错误详情") {
                        infoMultilineRow("原始错误", value: detail)
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
                        infoRow("图片附件", value: imageAttachmentSummary)
                    }
                }

                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    infoSection("工具调用 (\(toolCalls.count))") {
                        ForEach(Array(toolCalls.enumerated()), id: \.offset) { index, toolCall in
                            toolCallSummary(index: index + 1, toolCall: toolCall)
                        }
                    }
                }

                if !message.metadata.isEmpty {
                    infoSection("元数据") {
                        ForEach(sortedMetadataKeys, id: \.self) { key in
                            metadataRow(key: key, value: message.metadata[key] ?? "")
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 320)
        .frame(maxHeight: 460)
    }

    private var sortedMetadataKeys: [String] {
        message.metadata.keys.sorted()
    }

    private var imageAttachmentSummary: String {
        if let encoded = message.metadata["imageAttachments"], !encoded.isEmpty {
            return "\(encoded.count) 字符（Base64 JSON）"
        }
        return "是"
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
    private func metadataRow(key: String, value: String) -> some View {
        if shouldSummarizeMetadata(key: key, value: value) {
            infoRow(metadataLabel(for: key), value: metadataSummary(key: key, value: value), isMono: isMonoMetadata(key))
        } else if value.contains("\n") || value.count > 120 {
            infoMultilineRow(metadataLabel(for: key), value: value)
        } else {
            infoRow(metadataLabel(for: key), value: value, isMono: isMonoMetadata(key))
        }
    }

    @ViewBuilder
    private func toolCallSummary(index: Int, toolCall: LumiToolCall) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            infoRow("#\(index) 名称", value: toolCall.displayName ?? toolCall.name)
            infoRow("ID", value: toolCall.id, isMono: true)
            infoRow("参数", value: "\(toolCall.arguments.count) 字符")
            infoRow("结果", value: toolCallResultSummary(toolCall))
        }
        .padding(.vertical, 4)
    }

    private func toolCallResultSummary(_ toolCall: LumiToolCall) -> String {
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

    private func errorDetailSummary(for message: LumiChatMessage) -> String? {
        let resolved = ErrorTransportDetailsResolver.resolve(for: message)
        let summary = resolved.displaySummary
        return summary.isEmpty ? nil : summary
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

    private func metadataLabel(for key: String) -> String {
        switch key {
        case "thinkingContent": "思考内容"
        case "hasImages": "含图片"
        case "imageAttachments": "图片数据"
        case "isTransientStatus": "临时状态"
        case "source": "来源"
        case "language": "语言"
        case "automationLevel": "自动化"
        case "verbosity": "详细度"
        default: key
        }
    }

    private func shouldSummarizeMetadata(key: String, value: String) -> Bool {
        key == "thinkingContent" || key == "imageAttachments" || value.count > 200
    }

    private func metadataSummary(key: String, value: String) -> String {
        switch key {
        case "thinkingContent":
            return "\(value.count) 字符"
        case "imageAttachments":
            return "\(value.count) 字符（JSON）"
        default:
            return String(value.prefix(200)) + (value.count > 200 ? "…" : "")
        }
    }

    private func isMonoMetadata(_ key: String) -> Bool {
        key == "imageAttachments" || key.hasSuffix("ID") || key.hasSuffix("Id")
    }
}
