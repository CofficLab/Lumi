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
/// 「用户切换模型」时间线标记的主行文案。
///
/// 抽成纯函数便于单测：模型名相同、供应商不同时，主行必须带上供应商，
/// 否则会渲染成 `gpt-5 → gpt-5`，看起来什么都没变（#907）。
enum ModelSwitchSummary {
    struct Labels: Equatable {
        let source: String?
        let target: String
    }

    static func labels(
        fromProviderID: String?,
        fromModelName: String?,
        toProviderID: String?,
        toModelName: String?
    ) -> Labels {
        // 模型名相同、供应商不同：只显示模型名会变成 `gpt-5 → gpt-5`，
        // 看起来像没有切换，因此两端都补上供应商（#907）。
        if let fromModelName, let toModelName, fromModelName == toModelName,
           let fromProviderID, let toProviderID, fromProviderID != toProviderID {
            return Labels(
                source: "\(fromProviderID) · \(fromModelName)",
                target: "\(toProviderID) · \(toModelName)"
            )
        }

        return Labels(
            source: fromModelName ?? fromProviderID,
            target: toModelName ?? toProviderID ?? "未知模型"
        )
    }

    static func summaryText(
        fromProviderID: String?,
        fromModelName: String?,
        toProviderID: String?,
        toModelName: String?
    ) -> String {
        let labels = labels(
            fromProviderID: fromProviderID,
            fromModelName: fromModelName,
            toProviderID: toProviderID,
            toModelName: toModelName
        )
        guard let source = labels.source else {
            return "切换到 \(labels.target)"
        }
        return "\(source) → \(labels.target)"
    }
}

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
        ModelSwitchSummary.summaryText(
            fromProviderID: fromProviderID,
            fromModelName: fromModelName,
            toProviderID: toProviderID,
            toModelName: toModelName
        )
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
