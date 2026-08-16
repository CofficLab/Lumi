import LumiUI
import ProviderIdleTime
import SwiftUI

/// 24 小时活动热条：48 个半小时桶的可视化。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/ActivityHeatStripView.swift` 迁移而来。
public struct ActivityHeatStripView: View {
    @LumiTheme private var theme: any LumiUITheme

    public let scores: [Double]

    private let bucketCount = RestWindowInferencer.bucketsPerDay // 48
    private let cellWidth: CGFloat = 7
    private let cellSpacing: CGFloat = 2
    private let cellHeight: CGFloat = 24
    private let labelInset: CGFloat = 8

    /// 总宽度
    private var totalWidth: CGFloat {
        CGFloat(bucketCount) * cellWidth + CGFloat(bucketCount - 1) * cellSpacing
    }

    private var axisWidth: CGFloat {
        totalWidth + labelInset * 2
    }

    public init(scores: [Double]) {
        self.scores = scores
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("24-hour activity"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            heatmapWithLabels
        }
    }

    /// 格子网格和时间轴标签
    private var heatmapWithLabels: some View {
        VStack(alignment: .leading, spacing: 4) {
            gridCells
            gridLabels
        }
        .frame(width: axisWidth, alignment: .leading)
    }

    /// 格子网格
    private var gridCells: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<bucketCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: normalizedScore(at: index)))
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
        .padding(.horizontal, labelInset)
    }

    /// 时间轴标签 - 与整条 24 小时轴按比例对齐
    private var gridLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
                    .position(x: tickX(forHour: hour), y: 7)
            }
        }
        .frame(width: axisWidth, height: 14)
    }

    private func tickX(forHour hour: Int) -> CGFloat {
        labelInset + totalWidth * CGFloat(hour) / 24
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

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}
