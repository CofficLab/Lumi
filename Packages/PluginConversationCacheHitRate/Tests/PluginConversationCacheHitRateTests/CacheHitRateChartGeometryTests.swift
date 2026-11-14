import Foundation
import SwiftUI
import Testing
@testable import PluginConversationCacheHitRate

/// 缓存命中率折线图的几何量（见 issue #1224）。
///
/// hover 交互原先会重建全量点集；指示线改由 overlay 用 O(1) 计算绘制，
/// 因此单点坐标必须与全量映射完全一致。
@Suite("CacheHitRate 图表几何量")
struct CacheHitRateChartGeometryTests {

    private func makeSample(_ index: Int, hitRate: Double, cumulative: Double) -> CacheHitRateSample {
        CacheHitRateSample(
            id: UUID(),
            index: index,
            date: Date(timeIntervalSince1970: Double(index) * 60),
            hitRate: hitRate,
            cumulativeHitRate: cumulative,
            cachedTokens: 0,
            totalTokens: 0
        )
    }

    /// 与绘制层共用的映射规则（单点版本）。
    private func referencePoint(
        index: Int,
        count: Int,
        value: Double,
        size: CGSize,
        inset: EdgeInsets
    ) -> CGPoint {
        let plotWidth = max(size.width - inset.leading - inset.trailing, 1)
        let plotHeight = max(size.height - inset.top - inset.bottom, 1)
        let xRatio = count == 1 ? 0.5 : Double(index) / Double(count - 1)
        let yRatio = min(max(value, 0), 1)
        return CGPoint(
            x: inset.leading + plotWidth * xRatio,
            y: inset.top + plotHeight * (1 - yRatio)
        )
    }

    @Test("单点坐标与全量映射一致")
    func singlePointMatchesFullMapping() {
        let samples = [
            makeSample(0, hitRate: 0.1, cumulative: 0.2),
            makeSample(1, hitRate: 0.5, cumulative: 0.6),
            makeSample(2, hitRate: 0.9, cumulative: 0.95),
        ]
        let size = CGSize(width: 320, height: 110)
        let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        let geometry = ChartGeometry(size: size, inset: inset)

        for index in samples.indices {
            let single = geometry.point(at: index, in: samples.count, value: samples[index].hitRate)
            let expected = referencePoint(
                index: index,
                count: samples.count,
                value: samples[index].hitRate,
                size: size,
                inset: inset
            )
            #expect(single == expected)
        }
    }

    @Test("值域被钳制到 0...1")
    func valueIsClampedToUnitRange() {
        let samples = [makeSample(0, hitRate: -0.5, cumulative: 1.5)]
        let size = CGSize(width: 320, height: 110)
        let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        let geometry = ChartGeometry(size: size, inset: inset)

        let low = geometry.point(at: 0, in: 1, value: -0.5)
        let high = geometry.point(at: 0, in: 1, value: 1.5)

        // 纵轴固定 0...1：值 0 在底部、值 1 在顶部，越界值被钳到对应边界。
        #expect(low.y == geometry.plotBottom)
        #expect(high.y == geometry.plotTop)
    }
}
