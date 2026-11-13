import LumiUI
import PluginDevice
import SwiftUI

/// 存储明细区块：各卷容量条。
struct DeviceStatusStorageSection: View {
    @LumiTheme private var theme

    let volumes: [DeviceVolumeStatus]

    var body: some View {
        if volumes.isEmpty {
            Text(pluginLocalization.string("Unavailable"))
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(volumes, id: \.name) { volume in
                    volumeRow(volume)
                }
            }
        }
    }

    // MARK: - Row

    private func volumeRow(_ volume: DeviceVolumeStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: volume.isEjectable ? "externaldrive" : "internaldrive")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 16)

                Text(volume.name)
                    .font(.caption)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(Int(volume.usagePercentage.rounded()))%")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            ProgressView(value: min(max(volume.usagePercentage, 0), 100), total: 100)
                .tint(statusColor(for: volume.usagePercentage).color(in: theme))
                .controlSize(.mini)

            HStack(spacing: 4) {
                Text("\(formatBytes(volume.usedBytes)) / \(formatBytes(volume.totalBytes))")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)

                Spacer(minLength: 0)

                Text(pluginLocalization.string("free") + ": \(formatBytes(volume.availableBytes))")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(for percentage: Double) -> MetricStatus {
        MetricStatusScale.from(percentage: percentage)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}
