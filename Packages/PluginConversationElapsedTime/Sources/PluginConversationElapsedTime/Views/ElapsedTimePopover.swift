import SwiftUI

/// 模型用时详情弹窗：展示总用时与等待 / 生成拆分。
struct ElapsedTimePopover: View {
    let stats: ElapsedTimeStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView

            if stats.isEmpty {
                unavailableBlock
            } else {
                cardsSection
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(width: 320, alignment: .leading)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 18))
                .foregroundStyle(.teal)
            Text(pluginLocalization.string("LLM Time"))
                .font(.headline)
                .fixedSize()
            Spacer(minLength: 8)
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var cardsSection: some View {
        VStack(spacing: 10) {
            totalCard

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                usageCard(
                    icon: "hourglass",
                    title: pluginLocalization.string("First token wait"),
                    value: ElapsedTimeFormatter.compact(stats.firstTokenWaitMs / 1_000),
                    tint: .orange
                )
                usageCard(
                    icon: "bolt",
                    title: pluginLocalization.string("Generation"),
                    value: ElapsedTimeFormatter.compact(stats.generationMs / 1_000),
                    tint: .green
                )
            }
        }
    }

    /// 总用时卡片：主指标独占一行。
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sum")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pluginLocalization.string("Total time"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ElapsedTimeFormatter.compact(stats.totalSeconds))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }

                Spacer(minLength: 0)
            }

            Text(
                String(
                    format: pluginLocalization.string("%lld requests"),
                    stats.requestCount
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 32)
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

    private func usageCard(icon: String, title: String, value: String, tint: Color) -> some View {
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

    // MARK: - Unavailable

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(pluginLocalization.string("Elapsed time unavailable"))
                    .font(.subheadline.weight(.semibold))
                Text(
                    pluginLocalization.string(
                        "No conversation selected, or the model has not reported any timing yet."
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
