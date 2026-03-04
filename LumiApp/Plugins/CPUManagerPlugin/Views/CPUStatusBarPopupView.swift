import MagicKit
import SwiftUI

struct CPUStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CPUManagerViewModel()
    @ObservedObject private var historyService = CPUHistoryService.shared

    // MARK: - Body

    var body: some View {
        HoverableContainerView(detailView: CPUHistoryDetailView()) {
            VStack(spacing: 0) {
                // 实时负载显示
                liveLoadView

                // 历史趋势图（最近60秒）
                miniTrendView
            }
        }
    }

    // MARK: - Live Load View

    private var liveLoadView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CPU Usage")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Spacer()

                Text("\(Int(viewModel.cpuUsage))%")
                    .font(.system(size: 12, weight: .medium))
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))

                    // 进度条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DesignTokens.Color.semantic.info, DesignTokens.Color.semantic.primary]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.cpuUsage / 100.0))
                }
            }
            .frame(height: 6)
        }.padding()
    }

    // MARK: - Mini Trend View

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxValue = 100.0 // CPU usage is always 0-100%

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Text("Last 60 Seconds")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Spacer()

                // 图例
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(DesignTokens.Color.semantic.info.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Usage")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
                        .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.1), lineWidth: 1)
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
                                    DesignTokens.Color.semantic.info.opacity(0.4),
                                    DesignTokens.Color.semantic.primary.opacity(0.05),
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
                        .stroke(DesignTokens.Color.semantic.info.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text("收集中...")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glass.opacity(0.3))
    }
}

// MARK: - Preview

#Preview("App") {
    CPUStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
