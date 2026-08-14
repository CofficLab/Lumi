import SwiftUI

/// 流式速度详情弹窗：当前速度、平均速度、明细行与历史趋势。
struct SpeedPopover: View {
    let tps: Double?
    let unavailabilityReason: ConversationSpeedUnavailability
    let modelName: String?
    let outputTokens: Int?
    let streamingDurationMs: Double?
    let timeToFirstTokenMs: Double?
    let providerID: String?
    let speedHistory: [SpeedSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                Text(LumiPluginLocalization.string("Streaming Speed", bundle: .module))
                    .font(.headline)
                Spacer()
            }

            if let tps {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", tps))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text(LumiPluginLocalization.string("tokens / second", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                averageSpeedBlock

                Text(LumiPluginLocalization.string("Streaming speed description", bundle: .module))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                unavailableBlock
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let modelName, !modelName.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Model", bundle: .module),
                        value: modelName
                    )
                }
                if let outputTokens {
                    detailRow(
                        LumiPluginLocalization.string("Output tokens", bundle: .module),
                        value: "\(outputTokens)"
                    )
                }
                if let streamingDurationMs {
                    detailRow(
                        LumiPluginLocalization.string("Streaming duration", bundle: .module),
                        value: formatDuration(streamingDurationMs)
                    )
                }
                if let timeToFirstTokenMs {
                    detailRow(
                        LumiPluginLocalization.string("Time to first token", bundle: .module),
                        value: formatDuration(timeToFirstTokenMs)
                    )
                }
                if let providerID, !providerID.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Provider", bundle: .module),
                        value: providerID
                    )
                }
            }

            speedHistorySection

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LumiPluginLocalization.string("Speed unavailable", bundle: .module))
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

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2f s", ms / 1000.0)
        }
        return String(format: "%.0f ms", ms)
    }
}

// MARK: - 子区块

extension SpeedPopover {
    @ViewBuilder
    var averageSpeedBlock: some View {
        if let averageTPS = SpeedSample.averageTokensPerSecond(from: speedHistory) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LumiPluginLocalization.string("Average speed", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", averageTPS))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text(LumiPluginLocalization.string("tokens / second", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    var speedHistorySection: some View {
        if !speedHistory.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LumiPluginLocalization.string("Conversation speed trend", bundle: .module))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: LumiPluginLocalization.string("%d messages", bundle: .module), speedHistory.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LineChart(samples: speedHistory)
                    .frame(height: 118)

                HStack {
                    Text(String(format: LumiPluginLocalization.string("Min %.1f", bundle: .module), speedHistory.map(\.tokensPerSecond).min() ?? 0))
                    Spacer()
                    Text(String(format: LumiPluginLocalization.string("Max %.1f", bundle: .module), speedHistory.map(\.tokensPerSecond).max() ?? 0))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
