import SwiftUI

/// 菜单栏弹窗视图（CPU / 内存 / 磁盘 / 运行时间详情）。
///
/// 复刻自 Lumi DeviceInfoPlugin 的 DeviceInfoMenuBarPopupView（简化版）：
/// 用进度条展示 CPU / 内存，附加磁盘与运行时间。
public struct DeviceMenuBarPopupView: View {
    @StateObject private var data = DeviceData()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("设备信息")
                .font(.headline)

            metricRow(
                title: "CPU",
                value: String(format: "%.1f%%", data.cpuUsage),
                fraction: data.cpuUsage / 100,
                color: .accentColor
            )

            metricRow(
                title: "内存",
                value: "\(byteString(Int64(data.memoryUsed))) / \(byteString(Int64(data.memoryTotal)))",
                fraction: data.memoryUsage,
                color: .green
            )

            metricRow(
                title: "磁盘",
                value: "\(byteString(data.diskUsed)) / \(byteString(data.diskTotal))",
                fraction: data.diskTotal > 0 ? Double(data.diskUsed) / Double(data.diskTotal) : 0,
                color: .orange
            )

            HStack {
                Text("运行时间")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(uptimeString(data.uptime))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .frame(width: 220)
        .onDisappear {
            data.stopMonitoring()
        }
    }

    private func metricRow(title: String, value: String, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .monospacedDigit()
            }
            .font(.system(size: 11))

            ProgressView(value: fraction, total: 1)
                .tint(color)
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    private func uptimeString(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if days > 0 { return "\(days)天 \(hours)小时" }
        if hours > 0 { return "\(hours)小时 \(minutes)分钟" }
        return "\(minutes)分钟"
    }
}
