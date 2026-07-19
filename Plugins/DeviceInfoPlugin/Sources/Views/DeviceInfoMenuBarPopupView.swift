import LumiUI
import SwiftUI
import Combine

/// Menu bar popup view for Device Info plugin
/// Shows detailed CPU usage with progress bar and top processes
public struct DeviceInfoMenuBarPopupView: View {
    // MARK: - Properties

    @LumiTheme private var theme

    @StateObject private var viewModel = CPUManagerViewModel()

    // MARK: - Body

    var body: some View {
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
                    .foregroundColor(theme.textTertiary)

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
                        .fill(theme.textTertiary.opacity(0.2))

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
                        .fill(theme.success)
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("User %.0f%%", bundle: .module), viewModel.userUsage))
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(theme.warning)
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("Sys %.0f%%", bundle: .module), viewModel.systemUsage))
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(theme.textTertiary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(String(format: LumiPluginLocalization.string("Idle %.0f%%", bundle: .module), viewModel.idleUsage))
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding()
    }

    // MARK: - Top Processes View

    private var topProcessesView: some View {
        TopProcessesView(processes: viewModel.topProcesses)
    }

    // MARK: - Helpers

    private var cpuColor: Color {
        let value = viewModel.cpuUsage
        if value < 60 { return theme.success }
        if value < 85 { return theme.warning }
        return theme.error
    }
}

