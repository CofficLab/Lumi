import Foundation
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginConversationSpeed

/// 速度折线图的几何量（见 issue #1224）。
///
/// hover 交互原先会重建全量点集并重复扫描样本求值域，
/// 鼠标每移动一次就是一次全量重算。
@Suite("SpeedChartGeometry")
struct SpeedChartGeometryTests {

    private func makeSample(_ index: Int, tps: Double) -> SpeedSample {
        SpeedSample(
            id: UUID(),
            index: index,
            createdAt: Date(timeIntervalSince1970: Double(index) * 60),
            tokensPerSecond: tps,
            message: Message(conversationID: UUID(), role: .assistant, content: "")
        )
    }

    @Test("点集与逐点计算一致")
    func pointsMatchPointWiseComputation() {
        let samples = [makeSample(0, tps: 10), makeSample(1, tps: 20), makeSample(2, tps: 30)]
        let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        let geometry = SpeedChartGeometry(samples: samples, size: CGSize(width: 200, height: 100), inset: inset)

        let expected = samples.enumerated().map { offset, sample in
            let xRatio = Double(offset) / Double(samples.count - 1)
            let yRatio = (sample.tokensPerSecond - 10) / 20
            return CGPoint(
                x: inset.leading + geometry.plotWidth * xRatio,
                y: inset.top + geometry.plotHeight * (1 - yRatio)
            )
        }

        #expect(geometry.points == expected)
    }

    @Test("单点坐标与点集中的对应项一致")
    func singlePointMatchesPointsArray() {
        let samples = [makeSample(0, tps: 5), makeSample(1, tps: 50)]
        let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        let geometry = SpeedChartGeometry(samples: samples, size: CGSize(width: 200, height: 100), inset: inset)

        for index in samples.indices {
            let single = geometry.point(at: index, value: samples[index].tokensPerSecond)
            #expect(single == geometry.points[index])
        }
    }

    @Test("值域至少为 1，避免除零")
    func valueRangeHasFloor() {
        let samples = [makeSample(0, tps: 7), makeSample(1, tps: 7)]
        let geometry = SpeedChartGeometry(
            samples: samples,
            size: CGSize(width: 200, height: 100),
            inset: EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        )

        #expect(geometry.valueRange == 1)
    }

    @Test("空样本不崩溃")
    func emptySamplesAreSafe() {
        let geometry = SpeedChartGeometry(
            samples: [],
            size: CGSize(width: 200, height: 100),
            inset: EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        )

        #expect(geometry.points.isEmpty)
        #expect(geometry.minValue == 0)
        #expect(geometry.maxValue == 0)
    }

    @Test("单个样本落在水平中点")
    func singleSampleIsCentered() {
        let samples = [makeSample(0, tps: 42)]
        let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
        let geometry = SpeedChartGeometry(samples: samples, size: CGSize(width: 200, height: 100), inset: inset)

        let point = geometry.points[0]
        #expect(point.x == inset.leading + geometry.plotWidth / 2)
    }
}
