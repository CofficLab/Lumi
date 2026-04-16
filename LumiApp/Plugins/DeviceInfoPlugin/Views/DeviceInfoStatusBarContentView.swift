import SwiftUI
import Combine

/// 状态栏内容视图（CPU 每核瞬时柱状图）
struct DeviceInfoStatusBarContentView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = CPUManagerViewModel()
    
    // MARK: - Body
    
    var body: some View {
        Image(nsImage: CPUStatusBarChartRenderer.makeImage(from: viewModel.perCoreUsage))
            .interpolation(.none)
            .help(helpText)
    }
    
    // MARK: - Computed Properties
    
    private var helpText: String {
        let coreCount = viewModel.perCoreUsage.count
        return coreCount > 0
            ? String(format: "CPU %.0f%% · %d Cores", viewModel.cpuUsage, coreCount)
            : String(format: "CPU %.0f%%", viewModel.cpuUsage)
    }
}

// MARK: - Preview

#Preview("Device Info Status Bar Content") {
    HStack(spacing: 4) {
        Circle()
            .fill(AppUI.Color.semantic.info)
            .frame(width: 16, height: 16)
        
        DeviceInfoStatusBarContentView()
    }
    .padding()
}
