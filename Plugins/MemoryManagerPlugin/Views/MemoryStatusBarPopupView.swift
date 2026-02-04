import MagicKit
import SwiftUI

struct MemoryStatusBarPopupView: View {
    @StateObject private var viewModel = MemoryManagerViewModel()
    @ObservedObject private var historyService = MemoryHistoryService.shared

    var body: some View {
        HoverableContainerView(detailView: MemoryHistoryDetailView()) {
            VStack(spacing: 0) {
                liveStatsView

                // 历史趋势图（最近60秒）
                miniTrendView
            }
        }
    }

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("内存")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.usedMemory) / \(viewModel.totalMemory)")
                    .font(.system(size: 12, weight: .medium))
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
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.memoryUsagePercentage / 100.0))
                }
            }
            .frame(height: 6)
        }.padding()
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxValue = 100.0 // Memory usage is always 0-100%

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("最近60秒")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                // 图例
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.purple.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("使用率")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
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
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    }

                    // 内存使用率区域
                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple.opacity(0.4),
                                    Color.blue.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // 内存使用率线条
                        MiniGraphLine(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .stroke(Color.purple.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text("收集中...")
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
        .background(.background.opacity(0.3))
    }
}

// MARK: - Preview

#Preview("App") {
    MemoryStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
