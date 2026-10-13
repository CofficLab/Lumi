import SwiftUI
import UniformTypeIdentifiers

/// 缓存命中率详情弹窗。
///
/// 视觉结构与兄弟插件 `PluginConversationSpeed` 的 `SpeedPopover` 对齐：
/// 大图标标题行（右侧带导出按钮）→ 主指标卡片 → 2x2 统计卡网格 → 趋势区。
struct CacheHitRatePopover: View {
    let stats: CacheHitRateStats
    let history: CacheHitRateHistory
    let unavailabilityReason: CacheHitRateUnavailability

    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView

            if stats.sampleCount > 0 {
                cardsSection
            } else {
                unavailableBlock
            }

            trendSection

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "memorychip")
                .font(.system(size: 18))
                .foregroundStyle(.teal)
            Text(pluginLocalization.string("Cache Hit Rate"))
                .font(.headline)
                .fixedSize()
            Spacer(minLength: 8)
            Button(action: exportAsImage) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .opacity(isExporting ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            .help(pluginLocalization.string("Save as image"))
        }
    }

    // MARK: - Cards

    /// 卡片区：主指标独占一行，其余统计量在下一行两列排布。
    @ViewBuilder
    private var cardsSection: some View {
        VStack(spacing: 10) {
            currentRateCard

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                rateCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: pluginLocalization.string("Average hit rate"),
                    value: CacheHitRateLineChart.percentText(stats.averageHitRate),
                    tint: .blue
                )
                if let minimum = history.minimumHitRate {
                    rateCard(
                        icon: "arrow.down.right",
                        title: pluginLocalization.string("Lowest hit rate"),
                        value: CacheHitRateLineChart.percentText(minimum),
                        tint: .orange
                    )
                }
                if let maximum = history.maximumHitRate {
                    rateCard(
                        icon: "arrow.up.right",
                        title: pluginLocalization.string("Highest hit rate"),
                        value: CacheHitRateLineChart.percentText(maximum),
                        tint: .green
                    )
                }
                countCard
            }
        }
    }

    /// 主指标卡片：token 加权命中率，内嵌缓存 / 输入 token 总量作为副信息。
    ///
    /// 数字沿用分级配色（绿 / 橙 / 红），与工具栏按钮的语义保持一致。
    private var currentRateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pluginLocalization.string("Current hit rate"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(stats.precisePercentText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(hitRateColor)
                    }
                }

                Spacer(minLength: 0)
            }

            tokenSummaryRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.teal.opacity(0.18), lineWidth: 1)
        )
    }

    /// 主卡片副信息行：缓存 / 输入 token 总量。
    private var tokenSummaryRow: some View {
        HStack(spacing: 14) {
            tokenSummaryItem(
                icon: "arrow.down.circle",
                label: pluginLocalization.string("Cached tokens"),
                value: stats.totalCachedTokens.formatted(.number.grouping(.automatic))
            )
            tokenSummaryItem(
                icon: "arrow.up.circle",
                label: pluginLocalization.string("Total input tokens"),
                value: stats.totalInputTokens.formatted(.number.grouping(.automatic))
            )
        }
        .padding(.leading, 32)
    }

    private func tokenSummaryItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.teal.opacity(0.5))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary.opacity(0.7))
        }
    }

    /// 请求次数卡片。复用 `rateCard`，保持与其余统计量一致的排版。
    private var countCard: some View {
        rateCard(
            icon: "paperplane",
            title: pluginLocalization.string("Requests"),
            value: "\(stats.sampleCount)",
            tint: .teal
        )
    }

    private func rateCard(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Trend

    @ViewBuilder
    private var trendSection: some View {
        if stats.sampleCount > 0 {
            Divider()

            CacheHitRateTrendView(history: history)
        }
    }

    // MARK: - Unavailable

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(pluginLocalization.string("Cache hit rate unavailable"))
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

    // MARK: - Export

    /// 将卡片内容渲染为 PNG 并保存到用户选择的位置。
    @MainActor
    private func exportAsImage() {
        isExporting = true

        let renderer = ImageRenderer(content:
            VStack(alignment: .leading, spacing: 14) {
                headerView
                if stats.sampleCount > 0 {
                    cardsSection
                } else {
                    unavailableBlock
                }
                trendSection
            }
            .padding()
            .frame(width: 420, alignment: .leading)
            .background(Color(.windowBackgroundColor))
        )
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else {
            isExporting = false
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "cache-hit-rate.png"
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK, let url = panel.url else {
            isExporting = false
            return
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }

        isExporting = false
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
    .frame(width: 420)
}

#Preview("Cache Hit Rate Popover - Unavailable") {
    CacheHitRatePopover(
        stats: .empty,
        history: .empty,
        unavailabilityReason: .providerDidNotReportUsage
    )
    .frame(width: 420)
}
#endif
