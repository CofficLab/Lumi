import LumiUI
import SwiftUI

/// 上下文使用趋势：历史曲线 + 压缩标记 + 统计。
///
/// 作为 `ContextWindowPopover` 的一段，展示当前会话每次请求的输入规模变化。
struct ContextUsageTrendView: View {
    @LumiTheme private var theme

    let history: ContextUsageHistory

    private var chartPoints: [AppLineChartPoint] {
        history.samples.map { AppLineChartPoint(date: $0.date, value: Double($0.tokens)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if history.samples.isEmpty {
                emptyState
            } else {
                ZStack(alignment: .topLeading) {
                    AppLineChart(
                        points: chartPoints,
                        accessibilityLabel: String(
                            localized: "Context usage trend",
                            defaultValue: "上下文使用趋势",
                            bundle: .module
                        ),
                        valueLabel: { value in
                            Int(value).formattedContextSize
                        }
                    )
                    .frame(height: 118)

                    ContextUsageTrendMarkers(
                        markers: history.compactionMarkers,
                        sampleCount: history.samples.count
                    )
                }

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
        HStack {
            Text(String(localized: "Context usage trend", defaultValue: "上下文使用趋势", bundle: .module))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(
                String(
                    format: String(localized: "%lld requests", defaultValue: "%lld 次请求", bundle: .module),
                    history.samples.count
                )
            )
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
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
            if let average = history.averageTokens {
                statItem(
                    label: String(localized: "Avg", defaultValue: "平均", bundle: .module),
                    value: average
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

#if os(macOS)
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
