import SwiftUI

/// 缓存命中率趋势：历史双曲线 + 图例 + 统计。
///
/// 作为 `CacheHitRatePopover` 的一段，展示当前会话每次请求的缓存命中变化。
struct CacheHitRateTrendView: View {
    let history: CacheHitRateHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if history.isEmpty {
                emptyState
            } else {
                legend

                CacheHitRateLineChart(samples: history.samples)
                    .frame(height: 118)

                statsRow
            }
        }
    }
}

// MARK: - View

extension CacheHitRateTrendView {
    private var header: some View {
        HStack {
            Text(pluginLocalization.string("Cache hit rate trend"))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(String(format: pluginLocalization.string("%lld requests"), history.samples.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(lineWidth: 2.4, opacity: 1, label: pluginLocalization.string("Cumulative"))
            legendItem(lineWidth: 1.4, opacity: 0.55, label: pluginLocalization.string("This request"))
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(lineWidth: CGFloat, opacity: Double, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(Color.teal.opacity(opacity))
                .frame(width: 14, height: lineWidth)
            Text(label)
        }
    }

    private var emptyState: some View {
        Text(pluginLocalization.string("No cache usage history yet"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var statsRow: some View {
        HStack {
            if let minimum = history.minimumHitRate {
                statItem(label: pluginLocalization.string("Min"), value: minimum)
            }
            Spacer()
            if let average = history.averageHitRate {
                statItem(label: pluginLocalization.string("Avg"), value: average)
            }
            Spacer()
            if let maximum = history.maximumHitRate {
                statItem(label: pluginLocalization.string("Max"), value: maximum)
            }
        }
        .font(.caption)
    }

    private func statItem(label: String, value: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(CacheHitRateLineChart.percentText(value))
                .monospacedDigit()
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Cache Hit Rate Trend") {
    CacheHitRateTrendView(history: .preview)
        .padding()
        .frame(width: 320)
}

#Preview("Cache Hit Rate Trend - Empty") {
    CacheHitRateTrendView(history: .empty)
        .padding()
        .frame(width: 320)
}
#endif
