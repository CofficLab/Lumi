import LumiUI
import SwiftUI

/// 上下文使用趋势：历史曲线 + 压缩标记 + 统计。
///
/// 作为 `ContextPopover` 的一段，展示当前会话每次请求的输入规模变化。
///
/// 曲线按**固定间距**排布：请求次数少时铺满图表，请求次数多时保持间距并
/// 支持横向滚动，屏幕上的点密度不会随对话变长而变密。数据一个不丢，
/// 因此每一次压缩回落都仍然可见。
struct ContextUsageTrendView: View {
    @LumiTheme private var theme

    let history: ContextUsageHistory

    /// 曲线上相邻数据点的固定间距（点）。
    ///
    /// 8 点是「圆点不重叠」与「一屏能看足够多点」之间的平衡点。
    private static let pointSpacing: CGFloat = 8

    private var chartPoints: [AppLineChartPoint] {
        history.samples.map { AppLineChartPoint(date: $0.date, value: Double($0.tokens)) }
    }

    /// 压缩标记：锚定在「压缩发生的那次请求」之后。
    private var guides: [AppLineChartGuide] {
        history.compactionMarkers.map { marker in
            AppLineChartGuide(
                id: marker.id.uuidString,
                afterPointIndex: marker.afterSampleIndex,
                style: .warning
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if history.samples.isEmpty {
                emptyState
            } else {
                AppLineChart(
                    points: chartPoints,
                    accessibilityLabel: String(
                        localized: "Context usage trend",
                        defaultValue: "上下文使用趋势",
                        bundle: .module
                    ),
                    valueLabel: { value in
                        Int(value).formattedContextSize
                    },
                    fixedPointSpacing: Self.pointSpacing,
                    guides: guides,
                    // 横轴是请求序号而不是时间：同一天里的多次请求在日期标签下
                    // 完全无法区分，标成序号才与横轴的真实含义一致。
                    axisStyle: .index,
                    showsAxisTicks: true
                )
                .frame(height: 118)

                statsRow
            }

            if history.hasEstimatedSamples {
                estimatedNote
            }
        }
    }
}

// MARK: - View

extension ContextUsageTrendView {
    private var header: some View {
        Text(String(localized: "Context usage trend", defaultValue: "上下文使用趋势", bundle: .module))
            .font(.subheadline.weight(.semibold))
    }

    private var emptyState: some View {
        Text(String(localized: "No usage history yet", defaultValue: "暂无使用历史", bundle: .module))
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var statsRow: some View {
        HStack {
            if let minimum = history.minimumTokens {
                statItem(
                    label: String(localized: "Min", defaultValue: "最小", bundle: .module),
                    value: minimum
                )
            }
            Spacer()
            if let peak = history.peakTokens {
                statItem(
                    label: String(localized: "Max", defaultValue: "最大", bundle: .module),
                    value: peak
                )
            }
        }
        .font(.caption)
    }

    private func statItem(label: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Text(value.formattedContextSize)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
        }
    }

    private var estimatedNote: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 10))
            Text(String(
                localized: "Some points are estimated locally because the provider did not report usage.",
                defaultValue: "部分点由本地估算，因为供应商未上报用量。",
                bundle: .module
            ))
        }
        .font(.caption)
        .foregroundStyle(theme.textSecondary)
    }
}

// MARK: - Preview

#if DEBUG && os(macOS)
#Preview("Context Usage Trend - Large") {
    ContextUsageTrendView(history: .preview)
        .padding()
        .frame(width: 340, height: 280)
}

#Preview("Context Usage Trend - Empty") {
    ContextUsageTrendView(history: .empty)
        .padding()
        .frame(width: 340, height: 200)
}
#endif
