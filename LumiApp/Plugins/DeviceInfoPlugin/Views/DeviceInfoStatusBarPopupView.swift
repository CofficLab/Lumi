import SwiftUI
import Combine
import DeviceMonitorKit

/// Status bar popup view for Device Info plugin
/// Shows detailed CPU usage with progress bar and mini trend graph
struct DeviceInfoStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CPUManagerViewModel()
    @ObservedObject private var historyService = CPUHistoryService.shared

    // MARK: - Body

    var body: some View {
        HoverableContainerView(detailView: CPUHistoryDetailView()) {
            VStack(spacing: 0) {
                // 实时 CPU 负载显示
                liveCpuView

                // 历史趋势图（最近60秒）
                miniTrendView

                // Top 5 CPU 占用进程
                topProcessesView
            }
        }
    }

    // MARK: - Live CPU View

    private var liveCpuView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(localized: "CPU Usage", table: "DeviceInfo"))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "98989E"))

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
                        .fill(Color(hex: "98989E").opacity(0.2))

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
        }
        .padding()
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxValue: Double = 100.0 // CPU usage is 0-100%

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                Text(String(localized: "Last 60 Seconds", table: "DeviceInfo"))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                // 图例
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(cpuColor.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(String(localized: "Usage", table: "DeviceInfo"))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
                    }
                }
            }
            .padding(.horizontal, 12)

            // 迷你图表
            GeometryReader { geometry in
                ZStack {
                    // 背景网格线
                    ForEach(0 ..< 3) { i in
                        let y = CGFloat(i) * geometry.size.height / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color(hex: "98989E").opacity(0.1), lineWidth: 1)
                    }

                    // CPU 使用率区域
                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    cpuColor.opacity(0.4),
                                    cpuColor.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // CPU 使用率线条
                        MiniGraphLine(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .stroke(cpuColor.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text(String(localized: "Collecting...", table: "DeviceInfo"))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "98989E"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
    }

    // MARK: - Top Processes View

    private var topProcessesView: some View {
        TopProcessesView(processes: viewModel.topProcesses)
    }

    // MARK: - Helpers

    private var cpuColor: Color {
        let value = viewModel.cpuUsage
        if value < 60 { return Color(hex: "30D158") }
        if value < 85 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
}

// MARK: - Preview

#Preview("App") {
    DeviceInfoStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
