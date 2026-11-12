import LumiUI
import SwiftUI

/// CPU 明细区块：总占用 + 每核柱状图 + 负载均值 + user/system/idle 拆分。
struct DeviceStatusCPUSection: View {
    @LumiTheme private var theme

    let cpu: DeviceCPUStatus?

    var body: some View {
        if let cpu {
            VStack(alignment: .leading, spacing: 10) {
                headline(cpu)

                if !cpu.perCoreUsage.isEmpty {
                    perCoreBars(cpu.perCoreUsage)
                }

                if !cpu.loadAverage.isEmpty {
                    loadRow(cpu.loadAverage)
                }

                breakdown(cpu)
            }
        } else {
            unavailable
        }
    }

    // MARK: - Sections

    /// 顶部大号占用率。
    private func headline(_ cpu: DeviceCPUStatus) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(Int(cpu.usagePercentage.rounded()))%")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()

            Text(pluginLocalization.string("CPU Usage"))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: 0)
        }
    }

    /// 每核占用柱状图。
    private func perCoreBars(_ values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pluginLocalization.string("Per Core"))
                .font(.caption2)
                .foregroundStyle(theme.textTertiary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(statusColor(for: value).color(in: theme))
                        .frame(width: 8, height: max(2, 40 * min(max(value, 0), 100) / 100))
                }
            }
            .frame(height: 40, alignment: .bottom)
        }
    }

    /// 负载均值行。
    private func loadRow(_ load: [Double]) -> some View {
        HStack(spacing: 8) {
            Text(pluginLocalization.string("Load Average"))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            Text(load.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " / "))
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
    }

    /// user / system / idle 拆分。
    private func breakdown(_ cpu: DeviceCPUStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            breakdownRow(pluginLocalization.string("User"), cpu.userPercentage, theme.success)
            breakdownRow(pluginLocalization.string("System"), cpu.systemPercentage, theme.warning)
            breakdownRow(pluginLocalization.string("Idle"), cpu.idlePercentage, theme.textTertiary)
        }
    }

    private func breakdownRow(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44, alignment: .leading)

            ProgressView(value: min(max(value, 0), 100), total: 100)
                .tint(color)
                .controlSize(.mini)

            Text("\(Int(value.rounded()))%")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 38, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func statusColor(for value: Double) -> MetricStatus {
        MetricStatusScale.from(percentage: value)
    }

    private var unavailable: some View {
        Text(pluginLocalization.string("Unavailable"))
            .font(.caption)
            .foregroundStyle(theme.textTertiary)
    }
}
