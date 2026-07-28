import SwiftUI
import LumiUI
import LumiKernel

public struct ActivityHeatStripView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let scores: [Double]

    private let bucketCount = RestWindowInferencer.bucketsPerDay // 48
    private let cellWidth: CGFloat = 7
    private let cellSpacing: CGFloat = 2

    /// 每个格子的步进（宽度 + 间距）
    private var cellStep: CGFloat {
        cellWidth + cellSpacing
    }

    /// 总宽度
    private var totalWidth: CGFloat {
        CGFloat(bucketCount) * cellWidth + CGFloat(bucketCount - 1) * cellSpacing
    }

    public init(scores: [Double]) {
        self.scores = scores
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LumiPluginLocalization.string("24-hour activity", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            heatmapWithLabels
        }
    }

    /// 格子网格和时间轴标签
    private var heatmapWithLabels: some View {
        ZStack(alignment: .topLeading) {
            // 格子层
            gridCells

            // 标签层
            gridLabels
        }
        .frame(width: totalWidth)
    }

    /// 格子网格
    private var gridCells: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<bucketCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: normalizedScore(at: index)))
                    .frame(width: cellWidth, height: 24)
            }
        }
    }

    /// 时间轴标签 - 使用绝对偏移定位
    private var gridLabels: some View {
        ZStack(alignment: .topLeading) {
            // 00 - 第一个格子中心
            Text("00")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .offset(x: cellWidth / 2)

            // 06 - 12个格子后
            Text("06")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .offset(x: CGFloat(12) * cellStep + cellWidth / 2)

            // 12 - 24个格子后
            Text("12")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .offset(x: CGFloat(24) * cellStep + cellWidth / 2)

            // 18 - 36个格子后
            Text("18")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .offset(x: CGFloat(36) * cellStep + cellWidth / 2)

            // 24 - 最后一个格子中心
            Text("24")
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .offset(x: CGFloat(bucketCount - 1) * cellStep + cellWidth / 2)
        }
        .frame(width: totalWidth)
    }

    private func normalizedScore(at index: Int) -> Double {
        guard scores.indices.contains(index),
              let maxScore = scores.max(),
              maxScore > 0 else {
            return 0
        }
        return scores[index] / maxScore
    }

    private func color(for normalized: Double) -> Color {
        if normalized <= 0 {
            return theme.textSecondary.opacity(0.12)
        }
        return theme.primary.opacity(0.18 + normalized * 0.72)
    }
}
