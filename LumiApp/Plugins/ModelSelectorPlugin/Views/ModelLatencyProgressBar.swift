import SwiftUI

// MARK: - Model Latency Progress Bar

/// 模型耗时进度条组件
struct ModelLatencyProgressBar: View {
    let ttft: Double
    let totalLatency: Double
    let sampleCount: Int
    let tps: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // TTFT 部分（橙色）
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * ttftRatio)

                    // 响应时间部分（蓝色）
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (1 - ttftRatio))
                }
            }
            .frame(width: 80, height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))

            // 时间信息（一行显示）
            HStack(spacing: 6) {
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6, weight: .medium))
                    Text(ModelSelectorFormatService.durationMilliseconds(ttft))
                        .font(.caption2)
                }
                .foregroundColor(.orange)

                HStack(spacing: 1) {
                    Image(systemName: "clock")
                        .font(.system(size: 6, weight: .medium))
                    Text(ModelSelectorFormatService.durationMilliseconds(totalLatency))
                        .font(.caption2)
                }
                .foregroundColor(.blue)

                // TPS 显示
                if tps > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 6, weight: .medium))
                        Text(ModelSelectorFormatService.tps(tps))
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }

                if sampleCount > 1 {
                    Text("(\(sampleCount))")
                        .font(.caption2)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
            }
        }
        .help(helpText)
    }

    /// TTFT 占总耗时的比例
    private var ttftRatio: Double {
        guard totalLatency > 0 else { return 0 }
        return min(ttft / totalLatency, 1.0)
    }

    /// 帮助文本
    private var helpText: String {
        let ttftPercent = String(format: "%.1f", ttftRatio * 100)
        let responsePercent = String(format: "%.1f", (1 - ttftRatio) * 100)
        var text = """
        ⚡ TTFT: \(ModelSelectorFormatService.durationMilliseconds(ttft)) (\(ttftPercent)%)
        🕐 \(String(localized: "Response Time", table: "AgentChat")): \(ModelSelectorFormatService.durationMilliseconds(totalLatency)) (\(responsePercent)%)
        """

        if tps > 0 {
            text += "\n🚀 \(ModelSelectorFormatService.tps(tps))"
        }

        text += """


        \(String(localized: "TTFT Help", table: "AgentChat"))
        \(String(localized: "Response Time Help", table: "AgentChat"))
        """

        if tps > 0 {
            text += "\nTPS (Tokens Per Second)"
        }

        return text
    }
}
