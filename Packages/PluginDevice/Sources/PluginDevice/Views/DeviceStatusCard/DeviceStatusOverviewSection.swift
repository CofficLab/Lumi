import LumiUI
import SwiftUI

/// 设备状态总览区块：CPU / 内存 / GPU / 电池 / 磁盘 各一行。
///
/// 每个指标一行而非一格，是为了让「一屏看完」成立——
/// 卡片宽度有限，横排三格会把数字压得读不出来。
struct DeviceStatusOverviewSection: View {
    @LumiTheme private var theme

    let payload: DeviceStatusPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cpu = payload.cpu {
                metricRow(
                    icon: "cpu",
                    title: pluginLocalization.string("CPU"),
                    value: "\(Int(cpu.usagePercentage.rounded()))%",
                    ratio: cpu.usagePercentage / 100
                )
            }

            if let memory = payload.memory {
                metricRow(
                    icon: "memorychip",
                    title: pluginLocalization.string("Memory"),
                    value: "\(Int(memory.usagePercentage.rounded()))%",
                    ratio: memory.usagePercentage / 100,
                    detail: "\(formatBytes(memory.usedBytes)) / \(formatBytes(memory.totalBytes))"
                )
            }

            if let gpu = payload.gpu {
                metricRow(
                    icon: "sparkles",
                    title: pluginLocalization.string("GPU"),
                    value: "\(Int(gpu.utilizationPercentage.rounded()))%",
                    ratio: gpu.utilizationPercentage / 100
                )
            }

            if let battery = payload.battery, battery.hasBattery {
                metricRow(
                    icon: batteryIcon(battery),
                    title: pluginLocalization.string("Battery"),
                    value: "\(Int((battery.level * 100).rounded()))%",
                    ratio: battery.level,
                    detail: batteryDetail(battery)
                )
            }

            if let volume = payload.volumes.first {
                metricRow(
                    icon: "internaldrive",
                    title: pluginLocalization.string("Disk"),
                    value: "\(Int(volume.usagePercentage.rounded()))%",
                    ratio: volume.usagePercentage / 100,
                    detail: "\(formatBytes(volume.availableBytes)) \(pluginLocalization.string("free"))"
                )
            }
        }
    }

    // MARK: - Row

    private func metricRow(
        icon: String,
        title: String,
        value: String,
        ratio: Double,
        detail: String? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: min(max(ratio, 0), 1))
                    .tint(statusColor(for: ratio).color(in: theme))
                    .controlSize(.mini)

                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    /// 按占用比例映射状态色。
    private func statusColor(for ratio: Double) -> MetricStatus {
        MetricStatusScale.from(ratio: ratio)
    }

    /// 电池图标：充电 / 满电 / 普通。
    private func batteryIcon(_ battery: DeviceBatteryStatus) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        if battery.isCharged { return "battery.100" }
        return "battery.50"
    }

    /// 电池副标题：充电中 / 满电 / 健康度。
    private func batteryDetail(_ battery: DeviceBatteryStatus) -> String? {
        if battery.isCharging {
            return pluginLocalization.string("Charging")
        }
        if battery.healthPercentage > 0 {
            return pluginLocalization.string("Health") + ": \(Int(battery.healthPercentage))%"
        }
        return nil
    }

    /// 字节数格式化。
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    /// 字节数格式化。
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}
