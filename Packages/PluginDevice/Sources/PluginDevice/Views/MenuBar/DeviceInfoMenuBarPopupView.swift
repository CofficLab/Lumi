import LumiUI
import SwiftUI
import Combine

/// Menu bar popup view for Device Info plugin
/// Shows detailed CPU usage with progress bar and top processes
public struct DeviceInfoMenuBarPopupView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: CPUManagerViewModel
    @ObservedObject private var thermalViewModel: ThermalViewModel
    private let historyViewModel: DeviceHistoryViewModel<CPUDataPoint>
    private let thermalHistoryViewModel: DeviceHistoryViewModel<ThermalDataPoint>

    init(
        viewModel: CPUManagerViewModel,
        thermalViewModel: ThermalViewModel,
        historyViewModel: DeviceHistoryViewModel<CPUDataPoint>,
        thermalHistoryViewModel: DeviceHistoryViewModel<ThermalDataPoint>
    ) {
        self.viewModel = viewModel
        self.thermalViewModel = thermalViewModel
        self.historyViewModel = historyViewModel
        self.thermalHistoryViewModel = thermalHistoryViewModel
    }

    // MARK: - Body

    public var body: some View {
        HoverableContainerView(
            detailView: CPUHistoryDetailView(
                viewModel: historyViewModel,
                thermalViewModel: thermalHistoryViewModel
            )
        ) {
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
            // 紧凑指标行:使用率 + 温度(标题与数值并排,提高信息密度)
            HStack(spacing: 10) {
                metric(
                    label: pluginLocalization.string("Usage"),
                    value: String(format: "%.1f%%", viewModel.cpuUsage),
                    color: cpuColor
                )

                metric(
                    label: pluginLocalization.string("Temperature"),
                    value: temperatureText,
                    color: thermalViewModel.peakColor
                )

                Spacer(minLength: 0)
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
                    Text(String(format: pluginLocalization.string("User %.0f%%"), viewModel.userUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text(String(format: pluginLocalization.string("Sys %.0f%%"), viewModel.systemUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(String(format: pluginLocalization.string("Idle %.0f%%"), viewModel.idleUsage))
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

    /// 单个「标签 + 数值」指标块,用于首行的紧凑排布。
    private func metric(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }

    /// 最高温度文本;无温度传感器时用破折号占位(Intel Mac 等)。
    private var temperatureText: String {
        guard let peak = thermalViewModel.peakCelsius else { return "—" }
        return String(format: "%.1f°C", peak)
    }

    private var cpuColor: Color {
        let value = viewModel.cpuUsage
        if value < 60 { return .green }
        if value < 85 { return .orange }
        return .red
    }
}
