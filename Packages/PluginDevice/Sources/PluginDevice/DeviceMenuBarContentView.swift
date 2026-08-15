import SwiftUI

/// 菜单栏内容视图（CPU + 内存 简况）。
///
/// 复刻自 Lumi DeviceInfoPlugin 的 DeviceInfoMenuBarContentView（简化版）：
/// 用文本显示 CPU / 内存使用率，替代原 NSImage 柱状图。
public struct DeviceMenuBarContentView: View {
    @StateObject private var data = DeviceData()

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            // CPU
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                Text(String(format: "%.0f%%", data.cpuUsage))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
            }
            .help("CPU")

            // 内存
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10))
                Text(String(format: "%.0f%%", data.memoryUsage * 100))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
            }
            .help("内存")
        }
    }
}
