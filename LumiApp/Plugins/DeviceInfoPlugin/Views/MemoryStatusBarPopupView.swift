import MagicKit
import SwiftUI

struct MemoryStatusBarPopupView: View {
    @StateObject private var viewModel = MemoryManagerViewModel()
    @ObservedObject private var historyService = MemoryHistoryService.shared

    var body: some View {
        HoverableContainerView(detailView: MemoryHistoryDetailView()) {
            VStack(spacing: 0) {
                liveStatsView
                miniTrendView
            }
        }
    }

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Memory")
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Spacer()

                Text("\(viewModel.usedMemory) / \(viewModel.totalMemory)")
                    .font(.system(size: 12, weight: .medium))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppUI.Color.semantic.textTertiary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppUI.Color.semantic.primary, AppUI.Color.semantic.info]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.memoryUsagePercentage / 100.0))
                }
            }
            .frame(height: 6)
        }
        .padding()
    }

    private var miniTrendView: some View {
        let recentData = Array(historyService.recentHistory.suffix(60))
        let maxValue = 100.0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Text("Last 60 seconds")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Spacer()

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(AppUI.Color.semantic.primary.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Usage")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)

            GeometryReader { geometry in
                ZStack {
                    ForEach(0 ..< 3) { i in
                        let y = CGFloat(i) * geometry.size.height / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(AppUI.Color.semantic.textTertiary.opacity(0.1), lineWidth: 1)
                    }

                    if !recentData.isEmpty {
                        MiniGraphArea(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppUI.Color.semantic.primary.opacity(0.4),
                                    AppUI.Color.semantic.info.opacity(0.05),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        MiniGraphLine(
                            data: recentData.map { $0.usagePercentage },
                            maxValue: maxValue
                        )
                        .stroke(AppUI.Color.semantic.primary.opacity(0.8), lineWidth: 1.2)
                    } else {
                        Text("Collecting...")
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(AppUI.Material.glass.opacity(0.3))
    }
}

// MARK: - Preview

#Preview("App") {
    MemoryStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
