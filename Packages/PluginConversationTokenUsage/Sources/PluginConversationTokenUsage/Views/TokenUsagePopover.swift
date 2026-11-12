import SwiftUI

/// token 用量详情弹窗：展示总 token 数与输入 / 输出拆分。
struct TokenUsagePopover: View {
    let stats: TokenUsageStats

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
            Image(systemName: "number")
                .font(.system(size: 18))
                .foregroundStyle(.teal)
            Text(pluginLocalization.string("Token Usage"))
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
                    icon: "arrow.down.circle",
                    title: pluginLocalization.string("Input"),
                    value: stats.inputTokens.formatted(.number.grouping(.automatic)),
                    tint: .blue
                )
                usageCard(
                    icon: "arrow.up.circle",
                    title: pluginLocalization.string("Output"),
                    value: stats.outputTokens.formatted(.number.grouping(.automatic)),
                    tint: .green
                )
            }
        }
    }

    /// 总 token 卡片：主指标独占一行。
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sum")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pluginLocalization.string("Total tokens"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.totalTokens.formatted(.number.grouping(.automatic)))
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
                Text(pluginLocalization.string("Token usage unavailable"))
                    .font(.subheadline.weight(.semibold))
                Text(
                    pluginLocalization.string(
                        "No conversation selected, or the provider has not reported token usage yet."
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
