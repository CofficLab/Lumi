import LumiUI
import ProviderMessage
import SwiftUI

/// AgentLoop 自动重试时间线标记。
///
/// 主行只显示简短状态「正在重试（n/m）」，完整错误原因、HTTP 状态码等
/// 通过点击该行弹出 popover 查看，避免长错误消息把时间线挤成省略号。
struct AgentLoopRetryMessageView: View {
    @LumiTheme private var theme

    let message: Message

    @State private var showsDetail = false

    private let dividerHeight: CGFloat = 1

    // MARK: - Metadata

    private var attempt: Int? {
        MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.agentLoopRetryAttemptKey, from: message)
    }

    private var maxAttempts: Int? {
        MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.agentLoopRetryMaxAttemptsKey, from: message)
    }

    private var statusText: String {
        AgentLoopRetrySummary.statusText(attempt: attempt, maxAttempts: maxAttempts)
    }

    private var reason: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryReasonKey]
    }

    private var kind: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryKindKey]
    }

    private var httpStatus: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryHTTPStatusCodeKey]
    }

    /// 服务端建议的重试等待秒数。存在时说明重试不会立即发生。
    private var retryAfterSeconds: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryRetryAfterKey]
    }

    private var providerID: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryProviderIDKey]
    }

    private var modelName: String? {
        message.metadata[MessageTimelineEvent.agentLoopRetryModelNameKey]
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .medium))

            Text(statusText)
                .font(.appCaption)
                .lineLimit(1)

            Text(MessageViewHelpers.formatTimestamp(message.createdAt))
                .font(.system(size: 10))
                .lineLimit(1)

            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { showsDetail.toggle() }
        .popover(isPresented: $showsDetail, arrowEdge: .bottom) {
            detailPopover
        }
        .help(pluginLocalization.string("Tap to view retry details"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    // MARK: - Detail Popover

    @ViewBuilder
    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusText)
                .font(.subheadline.weight(.semibold))

            if let reason, !reason.isEmpty {
                detailRow(title: pluginLocalization.string("Reason"), body: reason)
            }
            if let kind, !kind.isEmpty {
                detailRow(title: pluginLocalization.string("Error Type"), body: kind)
            }
            if let httpStatus, !httpStatus.isEmpty {
                detailRow(title: pluginLocalization.string("HTTP Status Code"), body: httpStatus)
            }
            if let retryAfter = AgentLoopRetrySummary.retryAfterText(seconds: retryAfterSeconds) {
                detailRow(title: pluginLocalization.string("Wait"), body: retryAfter)
            }
            if let providerID, !providerID.isEmpty {
                detailRow(title: "Provider", body: providerID)
            }
            if let modelName, !modelName.isEmpty {
                detailRow(title: pluginLocalization.string("Model"), body: modelName)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
    }

    private func detailRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(body)
                .font(.caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
