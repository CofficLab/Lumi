import Foundation
import Testing

@testable import PluginLLMContext

/// 压缩标记横坐标定位的回归测试。
///
/// 关键不变式：标记的横坐标必须由**原始请求序号**决定，而不能由降采样后的
/// 可见点决定。否则曲线降采样后，压缩标记会指到错误的位置——而压缩回落
/// 恰恰是这张图最该被看见的信息。
struct ContextUsageTrendMarkersAlignmentTests {

    // MARK: - Constants

    /// 与 `AppLineChart` 一致的绘图区内边距。
    private let insetLeading: CGFloat = 14
    private let plotWidth: CGFloat = 300

    // MARK: - Basics

    @Test("早于首个采样点的压缩贴在左边缘")
    func markerBeforeFirstSampleSitsAtLeftEdge() {
        let x = ContextUsageTrendMarkers.markerXPosition(
            afterSampleIndex: -1,
            sampleCount: 10,
            plotWidth: plotWidth
        )

        #expect(x == insetLeading)
    }

    @Test("单个采样点时压缩标记落在中点")
    func singleSampleCentersMarker() {
        let x = ContextUsageTrendMarkers.markerXPosition(
            afterSampleIndex: 0,
            sampleCount: 1,
            plotWidth: plotWidth
        )

        #expect(x == insetLeading + plotWidth / 2)
    }

    @Test("压缩标记落在两个采样点之间而非压在点上")
    func markerSitsBetweenSamples() {
        // 4 个采样点，第 1 个之后压缩：应落在第 1、2 个点的中间。
        let x = ContextUsageTrendMarkers.markerXPosition(
            afterSampleIndex: 1,
            sampleCount: 4,
            plotWidth: plotWidth
        )

        let firstSampleX = insetLeading + plotWidth * (1.0 / 3.0)
        let secondSampleX = insetLeading + plotWidth * (2.0 / 3.0)
        let expected = (firstSampleX + secondSampleX) / 2

        #expect(abs(x - expected) < 0.001)
        #expect(x > firstSampleX)
        #expect(x < secondSampleX)
    }

    @Test("超出范围的采样下标被夹紧")
    func outOfRangeIndexIsClamped() {
        let x = ContextUsageTrendMarkers.markerXPosition(
            afterSampleIndex: 999,
            sampleCount: 5,
            plotWidth: plotWidth
        )

        let lastSampleX = insetLeading + plotWidth * (4.0 / 4.0)
        #expect(x <= lastSampleX)
        #expect(x >= insetLeading)
    }

    // MARK: - 与图表横坐标的一致性

    /// 降采样后，标记位置必须仍与图表中「原始序号对应的横坐标」一致。
    ///
    /// 图表的横坐标比例 = 原始下标 / (原始点数 - 1)；
    /// 标记的比例 = (下标 + 0.5) / (原始点数 - 1)，
    /// 即落在该采样点与其后继之间的中点。
    @Test("标记位置与图表原始序号横坐标保持一致", arguments: [10, 60, 300])
    func markerAlignsWithChartOriginalIndices(sampleCount: Int) {
        for afterIndex in 0..<(sampleCount - 1) {
            let x = ContextUsageTrendMarkers.markerXPosition(
                afterSampleIndex: afterIndex,
                sampleCount: sampleCount,
                plotWidth: plotWidth
            )

            // 图表中第 afterIndex 个采样点的横坐标。
            let sampleX = insetLeading + plotWidth * (CGFloat(afterIndex) / CGFloat(sampleCount - 1))
            // 该采样点之后的后继点横坐标。
            let nextSampleX = insetLeading + plotWidth * (CGFloat(afterIndex + 1) / CGFloat(sampleCount - 1))

            #expect(x > sampleX, "标记 \(afterIndex) 未落在采样点右侧")
            #expect(x < nextSampleX, "标记 \(afterIndex) 未落在后继点左侧")
        }
    }

    /// 标记横坐标必须单调递增，否则曲线上会出现标记顺序错乱。
    @Test("标记位置随采样下标单调递增")
    func markerPositionsAreMonotonic() {
        let sampleCount = 50
        var previous = -CGFloat.greatestFiniteMagnitude

        for afterIndex in 0..<(sampleCount - 1) {
            let x = ContextUsageTrendMarkers.markerXPosition(
                afterSampleIndex: afterIndex,
                sampleCount: sampleCount,
                plotWidth: plotWidth
            )
            #expect(x > previous)
            previous = x
        }
    }

    /// 压缩点在整条曲线上的位置必须始终落在绘图区内。
    @Test("标记不会超出绘图区")
    func markerStaysWithinPlotArea() {
        for sampleCount in [2, 5, 100, 1000] {
            for afterIndex in [-1, 0, sampleCount / 2, sampleCount - 1] {
                let x = ContextUsageTrendMarkers.markerXPosition(
                    afterSampleIndex: afterIndex,
                    sampleCount: sampleCount,
                    plotWidth: plotWidth
                )

                #expect(x >= insetLeading)
                #expect(x <= insetLeading + plotWidth)
            }
        }
    }
}
