import SwiftUI

/// 缓存命中率详情弹窗：当前概览、token 明细，以及历史趋势。
struct CacheHitRatePopover: View {
    let stats: CacheHitRateStats
    let history: CacheHitRateHistory
    let unavailabilityReason: CacheHitRateUnavailability

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(LumiPluginLocalization.string("Cache Hit Rate", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if stats.sampleCount > 0 {
                Text(stats.precisePercentText)
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(hitRateColor)

                Text(String(format: LumiPluginLocalization.string("%lld requests in this conversation", bundle: .module), stats.sampleCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                unavailableBlock
            }

            if stats.sampleCount > 0 {
                Divider()

                statRow(
                    icon: "arrow.down.circle",
                    label: LumiPluginLocalization.string("Cached tokens", bundle: .module),
                    value: stats.totalCachedTokens.formatted(.number.grouping(.automatic))
                )
                statRow(
                    icon: "arrow.up.circle",
                    label: LumiPluginLocalization.string("Total input tokens", bundle: .module),
                    value: stats.totalInputTokens.formatted(.number.grouping(.automatic))
                )
                statRow(
                    icon: "scalemass",
                    label: LumiPluginLocalization.string("Token-weighted rate", bundle: .module),
                    value: String(format: "%.1f%%", stats.weightedHitRate * 100)
                )
                statRow(
                    icon: "chart.bar",
                    label: LumiPluginLocalization.string("Per-request average", bundle: .module),
                    value: String(format: "%.1f%%", stats.averageHitRate * 100)
                )

                Divider()

                CacheHitRateTrendView(history: history)

                Divider()

                Text("命中率 = 缓存读取 tokens ÷ 总输入 tokens。该数值按 token 加权，缓存命中越高，重复上下文计费越低、响应越快。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: - View

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LumiPluginLocalization.string("Cache hit rate unavailable", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                Text(unavailabilityReason.localizedExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var hitRateColor: Color {
        switch stats.weightedHitRate {
        case 0.7...: return .green.opacity(0.9)
        case 0.4..<0.7: return .orange.opacity(0.95)
        default: return .red.opacity(0.9)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Cache Hit Rate Popover") {
    CacheHitRatePopover(
        stats: CacheHitRateStats.compute(messages: CacheHitRateHistory.previewMessages),
        history: .preview,
        unavailabilityReason: .waitingForResponse
    )
}

#Preview("Cache Hit Rate Popover - Unavailable") {
    CacheHitRatePopover(
        stats: .empty,
        history: .empty,
        unavailabilityReason: .providerDidNotReportUsage
    )
}
#endif
