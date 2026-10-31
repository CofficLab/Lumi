import LumiUI
import ProviderMessage
import SwiftUI

/// 「用户切换模型」时间线标记。
///
/// 主行展示「旧模型 → 新模型」，用分隔线把这条记录嵌进对话流，
/// 让用户在回看历史时知道「这一段回答换过模型」。
///
/// 完整信息（供应商 ID / 模型名 / 时间）通过点击该行弹出 popover 查看，
/// 避免长标识把时间线挤成省略号。
struct ModelSwitchMessageView: View {
    @LumiTheme private var theme

    let message: Message

    @State private var showsDetail = false

    /// 时间线横线的固定高度选 1pt，与其它时间线标记保持一致。
    private let dividerHeight: CGFloat = 1

    // MARK: - Metadata

    private var fromProviderID: String? {
        message.metadata[MessageTimelineEvent.modelSwitchedFromProviderIDKey]
    }

    private var fromModelName: String? {
        message.metadata[MessageTimelineEvent.modelSwitchedFromModelNameKey]
    }

    private var toProviderID: String? {
        message.metadata[MessageTimelineEvent.modelSwitchedToProviderIDKey]
    }

    private var toModelName: String? {
        message.metadata[MessageTimelineEvent.modelSwitchedToModelNameKey]
    }

    /// 切换后的模型名（主标签）。
    private var targetLabel: String {
        toModelName ?? toProviderID ?? "未知模型"
    }

    /// 切换前的模型名（次标签）；没有切换前模型时为 nil。
    private var sourceLabel: String? {
        fromModelName ?? fromProviderID
    }

    /// 主行的可读文本。
    private var summaryText: String {
        guard let sourceLabel else {
            return "切换到 \(targetLabel)"
        }
        return "\(sourceLabel) → \(targetLabel)"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)

            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 11, weight: .medium))

            Text(summaryText)
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
        .help("点击查看模型切换详情")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("模型切换：\(summaryText)")
    }

    // MARK: - Detail Popover

    @ViewBuilder
    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("模型切换")
                .font(.subheadline.weight(.semibold))

            if let sourceLabel {
                detailRow(title: "切换前", body: sourceLabel)
            }
            if let fromProviderID {
                detailRow(title: "原供应商", body: fromProviderID)
            }
            detailRow(title: "切换后", body: targetLabel)
            if let toProviderID {
                detailRow(title: "新供应商", body: toProviderID)
            }
            detailRow(title: "时间", body: MessageViewHelpers.formatTimestamp(message.createdAt))
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
