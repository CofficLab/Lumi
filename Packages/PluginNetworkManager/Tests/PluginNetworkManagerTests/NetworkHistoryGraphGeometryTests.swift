import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #732：历史图表按真实时间戳定位点与命中，而不是按数组下标等距布局。
@Suite("NetworkHistoryGraphGeometry")
@MainActor
struct NetworkHistoryGraphGeometryTests {

    @Test("时间空档按真实时长占据水平距离")
    func timeFractionsReflectSamplingGap() {
        // 前 5 个点每 10s 一个，随后 10 分钟空档，再连续 5 个点。
        let timestamps: [Double] = [0, 10, 20, 30, 40, 640, 650, 660, 670, 680]
        let points = timestamps.map {
            NetworkDataPoint(timestamp: $0, downloadSpeed: 1, uploadSpeed: 1)
        }

        let fractions = NetworkHistoryGraphView.timeFractions(for: points)

        #expect(fractions?.count == points.count)
        #expect(fractions?.first == 0)
        #expect(fractions?.last == 1)
        // 第 4 个点（t=40）只应占 40/680，而不是 4/9。
        #expect(abs((fractions?[4] ?? -1) - 40.0 / 680.0) < 0.0001)
        // 空档后第一个点（t=640）应远大于等距布局的 5/9。
        #expect((fractions?[5] ?? 0) > 0.9)
    }

    @Test("悬停按时间映射选取最近点，空档处不误选相邻序号")
    func hoverPicksPointByTimestamp() {
        let timestamps: [Double] = [0, 10, 20, 30, 40, 640, 650, 660, 670, 680]
        let points = timestamps.map {
            NetworkDataPoint(timestamp: $0, downloadSpeed: $0, uploadSpeed: 0)
        }

        // 空档正中间（t≈340）应命中空档先后两端中更近的一个，而不是下标 4/5 之间的等距点。
        let fraction = 340.0 / 680.0
        let index = NetworkHistoryGraphView.nearestIndex(forXFraction: fraction, in: points)

        #expect(index != nil)
        let timestamp = points[index!].timestamp
        #expect(abs(timestamp - 340) <= 300)
        // 右端命中最后一个点
        #expect(NetworkHistoryGraphView.nearestIndex(forXFraction: 1, in: points) == points.count - 1)
        // 左端命中第一个点
        #expect(NetworkHistoryGraphView.nearestIndex(forXFraction: 0, in: points) == 0)
    }

    @Test("点数不足或时间戳相同时退回等距布局")
    func degenerateInputsFallBackToEvenSpacing() {
        let single = [NetworkDataPoint(timestamp: 100, downloadSpeed: 1, uploadSpeed: 1)]
        #expect(NetworkHistoryGraphView.timeFractions(for: single) == nil)

        let sameTime = [
            NetworkDataPoint(timestamp: 100, downloadSpeed: 1, uploadSpeed: 1),
            NetworkDataPoint(timestamp: 100, downloadSpeed: 2, uploadSpeed: 2),
        ]
        #expect(NetworkHistoryGraphView.timeFractions(for: sameTime) == nil)
        #expect(NetworkHistoryGraphView.nearestIndex(forXFraction: 1, in: sameTime) == 1)
        #expect(NetworkHistoryGraphView.nearestIndex(forXFraction: 0, in: sameTime) == 0)
        #expect(NetworkHistoryGraphView.nearestIndex(forXFraction: 0.5, in: []) == nil)
    }
}
