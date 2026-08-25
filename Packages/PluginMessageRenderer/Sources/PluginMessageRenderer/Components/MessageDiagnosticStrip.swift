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

/// 消息正文下方的极简诊断信息条。
///
/// 只展示 `Message` 中尚未被 header / info 弹窗覆盖的高价值字段：
/// 响应耗时三件套（总耗时 / 首 token 延迟 / 流式时长）、渲染类型、期望渲染器。
/// 全部字段为空时整条隐藏，避免对普通文本消息产生噪音。
struct MessageDiagnosticStrip: View {
    @LumiTheme private var theme

    let message: Message

    private var summaryText: String? {
        var parts: [String] = []
        if let latency = message.latencyMs {
            parts.append("耗时 \(MessageViewHelpers.formatMilliseconds(latency))")
        }
        if let ttft = message.timeToFirstTokenMs {
            parts.append("首 token \(MessageViewHelpers.formatMilliseconds(ttft))")
        }
        if let streaming = message.streamingDurationMs {
            parts.append("流式 \(MessageViewHelpers.formatMilliseconds(streaming))")
        }
        if let renderKind = message.renderKind, !renderKind.isEmpty {
            parts.append("渲染 \(renderKind)")
        }
        if let preferred = message.preferredRendererID, !preferred.isEmpty {
            parts.append("期望 \(preferred)")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        if let summaryText {
            Text(summaryText)
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .help(summaryText)
        }
    }
}
