import LumiUI
import SwiftUI

/// Menu bar popup view for GPU monitoring.
/// Shows live GPU utilization with progress bar and mini trend graph.
struct GPUMenuBarPopupView: View {
    @ObservedObject private var viewModel: GPUManagerViewModel
    @ObservedObject private var historyViewModel: DeviceHistoryViewModel<GPUDataPoint>

    init(viewModel: GPUManagerViewModel, historyViewModel: DeviceHistoryViewModel<GPUDataPoint>) {
        self.viewModel = viewModel
        self.historyViewModel = historyViewModel
    }

    var body: some View {
        HoverableContainerView(detailView: GPUHistoryDetailView(viewModel: viewModel, historyViewModel: historyViewModel)) {
            VStack(spacing: 0) {
                liveStatsView
                miniTrendView
            }
        }
    }

    // MARK: - Live Stats View

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LumiPluginLocalization.string("GPU", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text(viewModel.utilizationString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(utilizationColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.8),
                                    .blue,
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.utilization / 100.0))
                }
            }
            .frame(height: 6)
        }
        .padding(10)
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyViewModel.recentHistory.suffix(60))
        let maxValue = 100.0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(LumiPluginLocalization.string("Last 60 Seconds", bundle: .module))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(LumiPluginLocalization.string("Usage", bundle: .module))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)

            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<3) { i in
                        let y = CGFloat(i) * geometry.size.height / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    }

                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.4),
                                    Color.blue.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        MiniGraphLine(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .stroke(Color.blue.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
    }

    private var utilizationColor: Color {
        let value = viewModel.utilization
        if value < 60 { return .green }
        if value < 85 { return .orange }
        return .red
    }
}
