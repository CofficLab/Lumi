import LumiUI
import SwiftUI
import Combine

/// Menu bar popup view for Device Info plugin
/// Shows detailed CPU usage with progress bar and top processes
public struct DeviceInfoMenuBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CPUManagerViewModel()

    // MARK: - Body

    public var body: some View {
        HoverableContainerView(detailView: CPUHistoryDetailView()) {
            VStack(spacing: 0) {
                // 实时 CPU 负载显示
                liveCpuView

                // Top 5 CPU 占用进程
                topProcessesView
            }
        }
    }

    // MARK: - Live CPU View

    private var liveCpuView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LumiPluginLocalization.string("CPU Usage", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f%%", viewModel.cpuUsage))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(cpuColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    // 进度条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [cpuColor.opacity(0.8), cpuColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.cpuUsage / 100.0))
                }
            }
            .frame(height: 6)

            // CPU usage breakdown: User / System
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("User %.0f%%", bundle: .module), viewModel.userUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("Sys %.0f%%", bundle: .module), viewModel.systemUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("Idle %.0f%%", bundle: .module), viewModel.idleUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
    }

    // MARK: - Top Processes View

    private var topProcessesView: some View {
        TopProcessesView(processes: viewModel.topProcesses)
    }

    // MARK: - Helpers

    private var cpuColor: Color {
        let value = viewModel.cpuUsage
        if value < 60 { return .green }
        if value < 85 { return .orange }
        return .red
    }
}
