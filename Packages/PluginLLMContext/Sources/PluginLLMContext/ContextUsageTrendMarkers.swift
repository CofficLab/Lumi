import LumiUI
import SwiftUI

/// 曲线上的压缩标记层。
///
/// 与 `AppLineChart` 保持相同的内边距与坐标映射，在每个压缩点画一条虚线。
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
    }
}

// MARK: - View

extension ContextUsageTrendMarkers {
    private func xPosition(for marker: ContextUsageCompactionMarker, plotWidth: CGFloat) -> CGFloat {
        // 早于首个采样点的压缩贴在左边缘，避免与第一个点重叠造成误读。
        guard marker.afterSampleIndex >= 0 else { return Self.inset.leading }
        guard sampleCount > 1 else { return Self.inset.leading + plotWidth / 2 }
        let clamped = min(marker.afterSampleIndex, sampleCount - 1)
        let ratio = CGFloat(clamped) / CGFloat(sampleCount - 1)
        return Self.inset.leading + plotWidth * ratio
    }
}
