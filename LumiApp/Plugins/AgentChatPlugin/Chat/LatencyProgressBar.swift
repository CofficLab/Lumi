import SwiftUI

// MARK: - Latency Progress Bar

/// 耗时进度条组件
/// 可视化显示首 token 延迟（TTFT）和总响应时间
struct LatencyProgressBar: View {
    /// 首 Token 延迟时间（毫秒）
    let ttft: Double
    /// 总响应时间（毫秒）
    let totalLatency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppDualSegmentBar(
                leadingRatio: ttftRatio,
                leadingColor: .orange,
                trailingColor: .blue
            )

            // 时间信息（一行显示）
            HStack(spacing: 8) {
                AppTag(formatTTFT(ttft), systemImage: "bolt.fill")
                AppTag(formatLatency(totalLatency), systemImage: "clock")
            }
        }
        .fixedSize()
        .help(helpText)
    }

    // MARK: - Computed Properties

    /// TTFT 占总耗时的比例
    private var ttftRatio: Double {
        guard totalLatency > 0 else { return 0 }
        return min(ttft / totalLatency, 1.0)
    }

    // MARK: - Helper Methods

    /// 格式化 TTFT
    /// - Parameter ttft: 首 Token 延迟时间（毫秒）
    /// - Returns: 格式化后的字符串
    private func formatTTFT(_ ttft: Double) -> String {
        if ttft >= 1000 {
            return String(format: "%.1fs", ttft / 1000.0)
        } else {
            return String(format: "%.0fms", ttft)
        }
    }

    /// 格式化响应时间
    /// - Parameter latency: 响应时间（毫秒）
    /// - Returns: 格式化后的字符串
    private func formatLatency(_ latency: Double) -> String {
        if latency < 1000 {
            return String(format: "%.0fms", latency)
        } else {
            return String(format: "%.1fs", latency / 1000.0)
        }
    }

    /// 帮助文本
    private var helpText: String {
        let ttftPercent = String(format: "%.1f", ttftRatio * 100)
        let responsePercent = String(format: "%.1f", (1 - ttftRatio) * 100)
        return """
        ⚡ 首个 Token 延迟 (TTFT): \(formatTTFT(ttft)) (\(ttftPercent)%)
        🕐 响应时间：\(formatLatency(totalLatency)) (\(responsePercent)%)

        TTFT 表示从发送请求到收到第一个 token 的时间
        响应时间表示从第一个 token 到响应完成的时间
        """
    }
}
