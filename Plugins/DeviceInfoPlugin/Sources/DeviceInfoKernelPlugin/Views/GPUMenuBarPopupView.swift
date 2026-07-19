import LumiUI
import SwiftUI

/// Menu bar popup view for GPU monitoring.
/// Shows live GPU utilization with progress bar and mini trend graph.
struct GPUMenuBarPopupView: View {
    @StateObject private var viewModel = GPUManagerViewModel()
    @ObservedObject private var historyService = GPUHistoryService.shared

    var body: some View {
        HoverableContainerView(detailView: GPUHistoryDetailView()) {
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
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                Text(viewModel.utilizationString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(viewModel.utilizationColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "98989E").opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "BF5AF2").opacity(0.8),
                                    Color(hex: "BF5AF2"),
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
        .padding()
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxValue = 100.0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                Text(LumiPluginLocalization.string("Last 60 Seconds", bundle: .module))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: "BF5AF2").opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(LumiPluginLocalization.string("Usage", bundle: .module))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
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
                        .stroke(Color(hex: "98989E").opacity(0.1), lineWidth: 1)
                    }

                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "BF5AF2").opacity(0.4),
                                    Color(hex: "BF5AF2").opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        MiniGraphLine(
                            data: recentData.map { $0.usage },
                            maxValue: maxValue
                        )
                        .stroke(Color(hex: "BF5AF2").opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
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
}
