import SwiftUI

/// 模型耗时进度条组件（设置专用版本）
/// 用于在设置页面展示模型的 TTFT、响应时间和 TPS 指标
struct SettingsModelLatencyBar: View {
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
                    Text(formatTTFT(ttft))
                        .font(.caption2)
                }
                .foregroundColor(.orange)

                HStack(spacing: 1) {
                    Image(systemName: "clock")
                        .font(.system(size: 6, weight: .medium))
                    Text(formatLatency(totalLatency))
                        .font(.caption2)
                }
                .foregroundColor(.blue)

                // TPS 显示
                if tps > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 6, weight: .medium))
                        Text(formatTPS(tps))
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }

                if sampleCount > 1 {
                    Text("(\(sampleCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

    /// 格式化 TTFT
    private func formatTTFT(_ ttft: Double) -> String {
        if ttft >= 1000 {
            return String(format: "%.1fs", ttft / 1000.0)
        } else {
            return String(format: "%.0fms", ttft)
        }
    }

    /// 格式化响应时间
    private func formatLatency(_ latency: Double) -> String {
        if latency >= 1000 {
            return String(format: "%.1fs", latency / 1000.0)
        } else {
            return String(format: "%.0fms", latency)
        }
    }

    /// 格式化 TPS
    private func formatTPS(_ tps: Double) -> String {
        if tps >= 100 {
            return String(format: "%.0f t/s", tps)
        } else if tps >= 10 {
            return String(format: "%.1f t/s", tps)
        } else {
            return String(format: "%.2f t/s", tps)
        }
    }

    /// 帮助文本
    private var helpText: String {
        let ttftPercent = String(format: "%.1f", ttftRatio * 100)
        let responsePercent = String(format: "%.1f", (1 - ttftRatio) * 100)
        var text = """
        ⚡ 首个 Token 延迟 (TTFT): \(formatTTFT(ttft)) (\(ttftPercent)%)
        🕐 响应时间: \(formatLatency(totalLatency)) (\(responsePercent)%)
        """

        if tps > 0 {
            text += "\n🚀 生成速度: \(formatTPS(tps))"
        }

        text += """
        
        
        TTFT 表示从发送请求到收到第一个 token 的时间
        响应时间表示从第一个 token 到响应完成的时间
        """

        if tps > 0 {
            text += "TPS (Tokens Per Second) 表示每秒生成的 token 数量"
        }

        return text
    }
}
