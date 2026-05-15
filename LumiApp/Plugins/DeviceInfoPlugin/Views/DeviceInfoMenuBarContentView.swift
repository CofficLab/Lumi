import SwiftUI
import Combine
import DeviceMonitorKit

/// 菜单栏内容视图（CPU 每核瞬时柱状图 + 内存单柱）
struct DeviceInfoMenuBarContentView: View {

    // MARK: - Properties

    @StateObject private var cpuViewModel = CPUManagerViewModel(monitorsProcesses: false)
    @StateObject private var memoryViewModel = MemoryManagerViewModel()

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            // CPU 柱状图
            Image(nsImage: CPUMenuBarChartRenderer.makeImage(from: cpuViewModel.perCoreUsage))
                .interpolation(.none)
                .help(cpuHelpText)

            // 内存柱状图
            Image(nsImage: MemoryMenuBarChartRenderer.makeImage(usage: memoryViewModel.memoryUsagePercentage))
                .interpolation(.none)
                .help(memoryHelpText)
        }
    }

    // MARK: - Computed Properties

    private var cpuHelpText: String {
        let coreCount = cpuViewModel.perCoreUsage.count
        if coreCount > 0 {
            return String(format: String(localized: "CPU %.0f%% · %d Cores", table: "DeviceInfo"), cpuViewModel.cpuUsage, coreCount)
        } else {
            return String(format: String(localized: "CPU %.0f%%", table: "DeviceInfo"), cpuViewModel.cpuUsage)
        }
    }

    private var memoryHelpText: String {
        String(localized: "Memory", table: "DeviceInfo") + " \(Int(memoryViewModel.memoryUsagePercentage))% · \(memoryViewModel.usedMemory) / \(memoryViewModel.totalMemory)"
    }
}

// MARK: - Preview

#Preview("Device Info Menu Bar Content") {
    HStack(spacing: 4) {
        Circle()
            .fill(Color(hex: "0A84FF"))
            .frame(width: 16, height: 16)
        
        DeviceInfoMenuBarContentView()
    }
    .padding()
}
