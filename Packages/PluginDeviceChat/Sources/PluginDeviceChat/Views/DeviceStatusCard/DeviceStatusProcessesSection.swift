import LumiUI
import PluginDevice
import SwiftUI

/// 进程排行区块：进程名 / CPU 占用 / 内存占用。
///
/// 同一进程可能有多份（浏览器 / IDE 的 Helper），因此标注份数；
/// Lumi 自身进程单独标注，方便用户确认是哪个应用在占资源。
struct DeviceStatusProcessesSection: View {
    @LumiTheme private var theme

    let processes: [DeviceProcessStatus]

    var body: some View {
        if processes.isEmpty {
            Text(pluginLocalization.string("Collecting..."))
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(processes, id: \.pid) { process in
                    processRow(process)
                }
            }
        }
    }

    // MARK: - Row

    private func processRow(_ process: DeviceProcessStatus) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            if process.instanceCount > 1 {
                Text("×\(process.instanceCount)")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }

            if process.isCurrentApp {
                Text(pluginLocalization.string("This App"))
                    .font(.caption2)
                    .foregroundStyle(theme.info)
            }

            Spacer(minLength: 4)

            Text(String(format: "%.1f%%", process.cpuPercentage))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .trailing)

            Text(formatBytes(process.memoryBytes))
                .font(.caption2)
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}
