import SwiftUI

/// 流式速度详情弹窗
struct SpeedPopover: View {
    let tps: Double?
    let unavailabilityReason: SpeedUnavailability
    let modelName: String?
    let outputTokens: Int?
    let streamingDurationMs: Double?
    let timeToFirstTokenMs: Double?
    let providerID: String?
    let messageCount: Int
    let speedHistory: [SpeedSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                Text(pluginLocalization.string("Streaming Speed"))
                    .font(.headline)
                    .fixedSize()
                Spacer(minLength: 8)
                if let routeLabel {
                    Text(routeLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(routeLabel)
                }
            }

            if let tps {
                speedCardsRow(currentTPS: tps)
            } else {
                unavailableBlock
            }

            Divider()

            // 供应商与模型已在标题行合并为 `provider/model`，此处不再重复。
            VStack(alignment: .leading, spacing: 8) {
                if let outputTokens {
                    detailRow(pluginLocalization.string("Output tokens"), value: "\(outputTokens)")
                }
                if let streamingDurationMs {
                    detailRow(pluginLocalization.string("Streaming duration"), value: formatDuration(streamingDurationMs))
                }
                if let timeToFirstTokenMs {
                    detailRow(pluginLocalization.string("Time to first token"), value: formatDuration(timeToFirstTokenMs))
                }
            }

            speedHistorySection

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 供应商/模型路由标签，如 `aliyun/qwen3.6-plus`。
    ///
    /// 任一环节缺失时降级为已有部分（例如只有模型名），两者都没有则不显示。
    private var routeLabel: String? {
        let provider = providerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelName?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (provider?.isEmpty == false ? provider : nil, model?.isEmpty == false ? model : nil) {
        case let (provider?, model?):
            return "\(provider)/\(model)"
        case let (provider?, nil):
            return provider
        case let (nil, model?):
            return model
        case (nil, nil):
            return nil
        }
    }

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(pluginLocalization.string("Speed unavailable"))
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
            return String(format: pluginLocalization.string("%.2f s"), ms / 1000.0)
        }
        return String(format: pluginLocalization.string("%.0f ms"), ms)
    }
}

// MARK: - Sub-sections

extension SpeedPopover {
    /// 速度区块：实时速度独占一行，平均 / 最高 / 最低与消息总数在下一行两列排布。
    ///
    /// 四个统计量必须齐备才显示第二行；任一缺失时整体隐藏该行，
    /// 避免出现落单的卡片破坏网格。
    @ViewBuilder
    func speedCardsRow(currentTPS: Double) -> some View {
        let values = speedHistory.map(\.tokensPerSecond)

        VStack(spacing: 10) {
            speedCard(
                icon: "bolt.fill",
                title: pluginLocalization.string("Current speed"),
                value: String(format: "%.1f", currentTPS),
                unit: pluginLocalization.string("tokens / second"),
                tint: .blue
            )

            if let averageTPS = SpeedSample.averageTokensPerSecond(from: speedHistory),
               let maxV = values.max(),
               let minV = values.min() {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    speedCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: pluginLocalization.string("Average speed"),
                        value: String(format: "%.1f", averageTPS),
                        unit: pluginLocalization.string("tokens / second"),
                        tint: .orange
                    )
                    speedCard(
                        icon: "arrow.down.right",
                        title: pluginLocalization.string("Lowest speed"),
                        value: String(format: "%.1f", minV),
                        unit: pluginLocalization.string("tokens / second"),
                        tint: .indigo
                    )
                    speedCard(
                        icon: "arrow.up.right",
                        title: pluginLocalization.string("Highest speed"),
                        value: String(format: "%.1f", maxV),
                        unit: pluginLocalization.string("tokens / second"),
                        tint: .green
                    )
                    messageCountCard()
                }
            }
        }
    }

    /// 会话消息总数卡片。复用 `speedCard`，保持与其余统计量一致的排版。
    private func messageCountCard() -> some View {
        speedCard(
            icon: "text.bubble",
            title: pluginLocalization.string("Messages in conversation"),
            value: "\(messageCount)",
            unit: pluginLocalization.string("messages"),
            tint: .teal
        )
    }

    private func speedCard(
        icon: String,
        title: String,
        value: String,
        unit: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    @ViewBuilder
    var speedHistorySection: some View {
        if !speedHistory.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(pluginLocalization.string("Conversation speed trend"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(speedHistory.count) messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SpeedLineChart(samples: speedHistory)
                    .frame(height: 118)
            }
        }
    }
}
