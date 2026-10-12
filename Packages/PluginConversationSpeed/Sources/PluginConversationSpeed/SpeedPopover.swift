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
    let requestCount: Int
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

            // TTFT / streaming duration / output tokens 已内嵌到实时速度卡片中。

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
        VStack(alignment: .leading, spacing: 8) {
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

            let subItems = buildSubInfoItems()
            if !subItems.isEmpty {
                speedSubInfoRow(subItems)
                    .padding(.top, 2)
            }
        }
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: pluginLocalization.string("%.2f s"), ms / 1000.0)
        }
        return String(format: pluginLocalization.string("%.0f ms"), ms)
    }

    /// 汇总卡片副信息项：TTFT、输出时长、输出令牌数，按固定顺序拼装。
    private func buildSubInfoItems() -> [(icon: String, label: String, value: String)] {
        var items: [(icon: String, label: String, value: String)] = []
        if let ttft = timeToFirstTokenMs {
            items.append((icon: "clock", label: pluginLocalization.string("TTFT"), value: formatDuration(ttft)))
        }
        if let duration = streamingDurationMs {
            items.append((icon: "timer", label: pluginLocalization.string("Duration"), value: formatDuration(duration)))
        }
        if let outputTokens {
            items.append((icon: "number", label: pluginLocalization.string("Tokens"), value: "\(outputTokens)"))
        }
        return items
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
            currentSpeedCard(tps: currentTPS)

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
                    requestCountCard()
                }
            }
        }
    }

    /// 实时速度卡片，内嵌首 Token 延迟、输出时长与输出令牌数作为副信息。
    ///
    /// 三个指标均来源于最后一条 assistant 消息，与实时速度语义同属一次响应，
    /// 放在同一卡片内比独立成行更紧凑，同时以次要样式保持视觉层级。
    private func currentSpeedCard(tps: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pluginLocalization.string("Current speed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", tps))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text(pluginLocalization.string("tokens / second"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            let subItems = buildSubInfoItems()
            if !subItems.isEmpty {
                speedSubInfoRow(subItems)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    /// 卡片内副信息行：小图标 + 标签 + 数值，用于 TTFT / 输出时长 / 输出令牌等次要指标。
    private func speedSubInfoRow(_ items: [(icon: String, label: String, value: String)]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue.opacity(0.5))
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
        }
        .padding(.leading, 32)
    }

    /// 请求次数卡片。复用 `speedCard`，保持与其余统计量一致的排版。
    private func requestCountCard() -> some View {
        speedCard(
            icon: "paperplane",
            title: pluginLocalization.string("Requests"),
            value: "\(requestCount)",
            unit: pluginLocalization.string("requests"),
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
                Text(pluginLocalization.string("Conversation speed trend"))
                    .font(.subheadline.weight(.semibold))

                SpeedLineChart(samples: speedHistory)
                    .frame(height: 118)
            }
        }
    }
}
