import LumiUI
import SwiftUI

/// 曲线上的压缩标记层。
///
/// 与 `AppLineChart` 保持相同的内边距与坐标映射，在每个压缩点画一条虚线。
///
/// 压缩标记的横坐标按**原始请求序号**定位，与图表内部一致：即使图表对数据
/// 做了降采样，标记仍落在正确的位置。
struct ContextUsageTrendMarkers: View {
    @LumiTheme private var theme

    let markers: [ContextUsageCompactionMarker]
    let sampleCount: Int

    private static let inset = EdgeInsets(top: 14, leading: 14, bottom: 24, trailing: 14)

    var body: some View {
        GeometryReader { proxy in
            let plotWidth = max(proxy.size.width - Self.inset.leading - Self.inset.trailing, 1)
            let plotHeight = max(proxy.size.height - Self.inset.top - Self.inset.bottom, 1)

            ZStack(alignment: .topLeading) {
                ForEach(markers) { marker in
                    Path { path in
                        let x = xPosition(for: marker, plotWidth: plotWidth)
                        path.move(to: CGPoint(x: x, y: Self.inset.top))
                        path.addLine(to: CGPoint(x: x, y: Self.inset.top + plotHeight))
                    }
                    .stroke(
                        theme.warning.opacity(0.75),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 118)
    }
}

// MARK: - View

extension ContextUsageTrendMarkers {
    /// 压缩标记的横坐标。
    ///
    /// 压缩发生在第 `afterSampleIndex` 个采样点**之后**、下一个采样点之前，
    /// 因此标记落在两个采样点之间的中点，而不是压在某个采样点上。
    ///
    /// 比例以**原始请求序号**为基准，与图表内部的横坐标算法一致：
    /// 图表降采样后标记依然落在正确位置。
    private func xPosition(for marker: ContextUsageCompactionMarker, plotWidth: CGFloat) -> CGFloat {
        Self.markerXPosition(
            afterSampleIndex: marker.afterSampleIndex,
            sampleCount: sampleCount,
            plotWidth: plotWidth
        )
    }

    /// 压缩标记横坐标的纯计算。
    ///
    /// - Parameters:
    ///   - afterSampleIndex: 压缩发生在第几个采样点之后；`-1` 表示早于首个采样点。
    ///   - sampleCount: 采样点总数。
    ///   - plotWidth: 绘图区宽度（不含内边距）。
    static func markerXPosition(
        afterSampleIndex: Int,
        sampleCount: Int,
        plotWidth: CGFloat
    ) -> CGFloat {
        // 早于首个采样点的压缩贴在左边缘，避免与第一个点重叠造成误读。
        guard afterSampleIndex >= 0 else { return inset.leading }
        guard sampleCount > 1 else { return inset.leading + plotWidth / 2 }
        let clamped = min(afterSampleIndex, sampleCount - 1)
        // 标记落在该采样点与其后继之间的中点；发生在最后一个点之后时贴住右边缘。
        let ratio = min((CGFloat(clamped) + 0.5) / CGFloat(sampleCount - 1), 1)
        return inset.leading + plotWidth * ratio
    }
}
