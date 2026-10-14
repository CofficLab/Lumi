import SwiftUI

/// 缓存命中率趋势：标题 + 双曲线图例 + 折线图。
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
            }
        }
    }
}

// MARK: - View

extension CacheHitRateTrendView {
    private var header: some View {
        Text(pluginLocalization.string("Cache hit rate trend"))
            .font(.subheadline.weight(.semibold))
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
