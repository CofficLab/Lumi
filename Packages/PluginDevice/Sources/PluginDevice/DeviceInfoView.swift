import SwiftUI

/// 设备信息详情视图。
///
/// 展示设备静态信息（名称 / OS / 处理器 / 核心数）与动态指标
/// （CPU / 内存 / 磁盘 / 电池 / 运行时间），每 2 秒刷新。
public struct DeviceInfoView: View {
    @StateObject private var data = DeviceData()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设备信息")
                .font(.title2)

            // 静态信息
            GroupBox("系统") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    infoRow("设备名称", data.deviceName)
                    infoRow("系统版本", data.osVersion)
                    infoRow("处理器", data.processorName)
                    infoRow("核心数", "\(data.coreCount)")
                }
                .padding(.vertical, 4)
            }

            // 动态指标
            GroupBox("指标") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    infoRow("CPU", percent(data.cpuUsage))
                    infoRow("内存", "\(percent(data.memoryUsage)) · \(byteString(Int64(data.memoryUsed))) / \(byteString(Int64(data.memoryTotal)))")
                    infoRow("磁盘", "\(byteString(data.diskUsed)) / \(byteString(data.diskTotal))")
                    if data.batteryLevel > 0 {
                        infoRow("电池", "\(Int(data.batteryLevel * 100))%\(data.isCharging ? " · 充电中" : "")")
                    }
                    infoRow("运行时间", uptimeString(data.uptime))
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear {
            data.stopMonitoring()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .gridColumnAlignment(.leading)
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
