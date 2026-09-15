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
            Text(LumiPluginLocalization.string("Cache hit rate trend", bundle: .module))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(String(format: LumiPluginLocalization.string("%lld requests", bundle: .module), history.samples.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(lineWidth: 2.4, opacity: 1, label: LumiPluginLocalization.string("Cumulative", bundle: .module))
            legendItem(lineWidth: 1.4, opacity: 0.55, label: LumiPluginLocalization.string("This request", bundle: .module))
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
        Text(LumiPluginLocalization.string("No cache usage history yet", bundle: .module))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var statsRow: some View {
        HStack {
            if let minimum = history.minimumHitRate {
                statItem(label: LumiPluginLocalization.string("Min", bundle: .module), value: minimum)
            }
            Spacer()
            if let average = history.averageHitRate {
                statItem(label: LumiPluginLocalization.string("Avg", bundle: .module), value: average)
            }
            Spacer()
            if let maximum = history.maximumHitRate {
                statItem(label: LumiPluginLocalization.string("Max", bundle: .module), value: maximum)
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
