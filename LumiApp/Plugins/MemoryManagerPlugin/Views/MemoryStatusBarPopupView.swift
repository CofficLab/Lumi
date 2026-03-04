import MagicKit
import SwiftUI

struct MemoryStatusBarPopupView: View {
    @StateObject private var viewModel = MemoryManagerViewModel()
    @ObservedObject private var historyService = MemoryHistoryService.shared

    var body: some View {
        HoverableContainerView(detailView: MemoryHistoryDetailView()) {
            VStack(spacing: 0) {
                liveStatsView

                // History trend chart (last 60 seconds)
                miniTrendView
            }
        }
    }

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Memory")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Spacer()

                Text("\(viewModel.usedMemory) / \(viewModel.totalMemory)")
                    .font(.system(size: 12, weight: .medium))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))

                    // Progress bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.info]),
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
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Text("Last 60 seconds")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Spacer()

                // Legend
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(DesignTokens.Color.semantic.primary.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Usage")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)

            // Mini chart
            GeometryReader { geometry in
                ZStack {
                    // Background grid lines
                    ForEach(0 ..< 3) { i in
                        let y = CGFloat(i) * geometry.size.height / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.1), lineWidth: 1)
                    }

                    // Memory usage area
                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    DesignTokens.Color.semantic.primary.opacity(0.4),
                                    DesignTokens.Color.semantic.info.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Memory usage line
                        MiniGraphLine(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .stroke(DesignTokens.Color.semantic.primary.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text("Collecting...")
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
    MemoryStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
