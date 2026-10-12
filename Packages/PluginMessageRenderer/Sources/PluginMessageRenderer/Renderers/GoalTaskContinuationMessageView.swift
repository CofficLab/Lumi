import LumiUI
import ProviderMessage
import SwiftUI

/// Goal 自动续跑时间线标记。
struct GoalTaskContinuationMessageView: View {
    @LumiTheme private var theme

    let message: Message

    @State private var showsDetail = false

    private var action: String? {
        message.metadata[MessageTimelineEvent.goalTaskContinuationActionKey]
    }

    private var attempt: Int? {
        MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.goalTaskContinuationAttemptKey, from: message)
    }

    private var maxAttempts: Int? {
        MessageTimelineEvent.integerMetadata(
            MessageTimelineEvent.goalTaskContinuationMaxAttemptsKey, from: message)
    }

    private var isLimitReached: Bool {
        action == MessageTimelineEvent.goalTaskContinuationLimitReached
    }

    private var statusText: String {
        if isLimitReached {
            return "Goal 自动续跑已停止"
        }
        if let attempt, let maxAttempts {
            return "Goal 自动继续（\(attempt)/\(maxAttempts)）"
        }
        return "Goal 自动继续"
    }

    private var reason: String? {
        message.metadata[MessageTimelineEvent.goalTaskContinuationReasonKey]
    }

    private var goalTitles: [String] {
        guard let value = message.metadata[MessageTimelineEvent.goalTaskContinuationGoalTitlesKey]
        else { return [] }
        return value.split(separator: "\n").map(String.init)
    }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            Image(systemName: isLimitReached ? "stop.circle" : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 11, weight: .medium))

            Text(statusText)
                .font(.appCaption)
                .lineLimit(1)

            Text(MessageViewHelpers.formatTimestamp(message.createdAt))
                .font(.system(size: 10))
                .lineLimit(1)

            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(isLimitReached ? theme.warning : theme.textSecondary)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { showsDetail.toggle() }
        .popover(isPresented: $showsDetail, arrowEdge: .bottom) {
            detailPopover
        }
        .help("点击查看 Goal 自动续跑详情")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    @ViewBuilder
    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusText)
                .font(.subheadline.weight(.semibold))

            if let reason, !reason.isEmpty {
                detailRow(title: "说明", body: reason)
            }
            if !goalTitles.isEmpty {
                detailRow(title: "相关 Goal", body: goalTitles.joined(separator: "\n"))
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
