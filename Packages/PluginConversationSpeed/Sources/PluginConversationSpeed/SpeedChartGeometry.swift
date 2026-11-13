import SwiftUI

/// 速度折线图的几何量。
///
/// 采样点的坐标映射需要知道全体样本的最小值与最大值（纵轴按值域缩放），
/// 因此每次 hover 移动若都重新扫描全体样本就是 O(N)。
///
/// 这里把值域随样本一起缓存：样本数组不变时值域不变，
/// 于是 hover 交互只需 O(1) 就能算出目标点的坐标
/// （见 issue #1224）。
struct SpeedChartGeometry {
    /// 样本数组。
    let samples: [SpeedSample]
    /// 画布内边距。
    let inset: EdgeInsets
    /// 绘图区尺寸。
    let plotWidth: CGFloat
    let plotHeight: CGFloat

    /// 样本值的最小值。
    let minValue: Double
    /// 样本值的最大值。
    let maxValue: Double

    init(samples: [SpeedSample], size: CGSize, inset: EdgeInsets) {
        self.samples = samples
        self.inset = inset
        self.plotWidth = max(size.width - inset.leading - inset.trailing, 1)
        self.plotHeight = max(size.height - inset.top - inset.bottom, 1)

        var minValue = Double.infinity
        var maxValue = -Double.infinity
        for sample in samples {
            minValue = min(minValue, sample.tokensPerSecond)
            maxValue = max(maxValue, sample.tokensPerSecond)
        }
        if samples.isEmpty {
            minValue = 0
            maxValue = 0
        }
        self.minValue = minValue
        self.maxValue = maxValue
    }

    /// 纵轴值域跨度；全等值时至少为 1，避免除零。
    var valueRange: Double {
        max(maxValue - minValue, 1)
    }

    /// 全体样本点。
    var points: [CGPoint] {
        samples.enumerated().map { offset, sample in
            point(at: offset, value: sample.tokensPerSecond)
        }
    }

    /// 单个样本点的画布坐标；O(1)。
    func point(at index: Int, value: Double) -> CGPoint {
        let xRatio = samples.count == 1 ? 0.5 : Double(index) / Double(samples.count - 1)
        let yRatio = (value - minValue) / valueRange
        return CGPoint(
            x: inset.leading + plotWidth * xRatio,
            y: inset.top + plotHeight * (1 - yRatio)
        )
    }
}
