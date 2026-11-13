import LumiUI
import PluginDevice
import SwiftUI

/// 内存明细区块：已用 / 总量 / 占用率 / 内存压力等级。
struct DeviceStatusMemorySection: View {
    @LumiTheme private var theme

    let memory: DeviceMemoryStatus?

    var body: some View {
        if let memory {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(memory.usagePercentage.rounded()))%")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()

                    Text(pluginLocalization.string("Memory Usage"))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Spacer(minLength: 0)
                }

                ProgressView(value: min(max(memory.usagePercentage, 0), 100), total: 100)
                    .tint(statusColor(for: memory.usagePercentage).color(in: theme))
                    .controlSize(.small)

                HStack(spacing: 8) {
                    Text(formatBytes(memory.usedBytes))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()

                    Text("/")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)

                    Text(formatBytes(memory.totalBytes))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()

                    Spacer(minLength: 0)

                    Text(pluginLocalization.string("Pressure") + ": \(memory.pressure)")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        } else {
            Text(pluginLocalization.string("Unavailable"))
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Helpers

    private func statusColor(for percentage: Double) -> MetricStatus {
        MetricStatusScale.from(percentage: percentage)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }
}
