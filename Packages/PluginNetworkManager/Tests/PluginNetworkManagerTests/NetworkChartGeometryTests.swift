import Foundation
import Testing
@testable import PluginNetworkManager

/// 图表几何量与历史裁剪缓存（见 issue #1211）。
///
/// 原先每次 body 求值要跑 4 次全量 map 加 2 次全量扫描，
/// 鼠标在图上每移动一次就重跑一遍；`data(for:)` 也会重新做一次线性裁剪。
@Suite("Network 图表几何量")
@MainActor
struct NetworkChartGeometryTests {

    private func makePoints(_ count: Int) -> [NetworkDataPoint] {
        (0..<count).map { index in
            NetworkDataPoint(
                timestamp: Double(index) * 60,
                downloadSpeed: Double(index) * 100,
                uploadSpeed: Double(index) * 10
            )
        }
    }

    @Test("几何量与逐点计算一致")
    func geometryMatchesPointWiseComputation() {
        let points = makePoints(50)
        let geometry = ChartGeometry(points: points)

        #expect(geometry.downloadValues == points.map(\.downloadSpeed))
        #expect(geometry.uploadValues == points.map(\.uploadSpeed))
    }

    @Test("最大值取上下行两者的较大值并留 10% 余量")
    func maxValueUsesBothSeries() {
        let points = [
            NetworkDataPoint(timestamp: 0, downloadSpeed: 100, uploadSpeed: 50),
            NetworkDataPoint(timestamp: 1, downloadSpeed: 20, uploadSpeed: 900),
        ]
        let geometry = ChartGeometry(points: points)

        let expected = max(max(100.0, 900.0) * 1.1, 1024 * 10)
        #expect(geometry.maxValue == expected)
    }

    @Test("最大值有最小刻度下限")
    func maxValueHasFloor() {
        let points = [NetworkDataPoint(timestamp: 0, downloadSpeed: 1, uploadSpeed: 1)]
        let geometry = ChartGeometry(points: points)

        #expect(geometry.maxValue == 1024 * 10)
    }

    @Test("空数据的几何量不崩溃")
    func emptyPointsProduceEmptyGeometry() {
        let geometry = ChartGeometry(points: [])

        #expect(geometry.downloadValues.isEmpty)
        #expect(geometry.uploadValues.isEmpty)
        #expect(geometry.timeFractions == nil)
    }

    @Test("时间位置与 timeFractions 一致")
    func timeFractionsMatchStaticHelper() {
        let points = makePoints(20)
        let geometry = ChartGeometry(points: points)

        #expect(geometry.timeFractions == NetworkHistoryGraphView.timeFractions(for: points))
    }

    @Test("裁剪结果按范围缓存，缓冲变化后失效")
    func rangeCacheInvalidatesOnBufferChange() {
        let viewModel = NetworkHistoryViewModel()
        let now = Date().timeIntervalSince1970
        let points = [
            NetworkDataPoint(timestamp: now - 10, downloadSpeed: 1, uploadSpeed: 1),
            NetworkDataPoint(timestamp: now - 5000, downloadSpeed: 2, uploadSpeed: 2),
        ]
        viewModel.apply(recent: points, longTerm: points)

        let first = viewModel.data(for: .hour1)
        let second = viewModel.data(for: .hour1)
        #expect(first.count == second.count)
        #expect(first.count == 1)

        // 缓冲更新后缓存必须失效。
        viewModel.apply(
            recent: points + [NetworkDataPoint(timestamp: now, downloadSpeed: 3, uploadSpeed: 3)],
            longTerm: points
        )
        let third = viewModel.data(for: .hour1)
        #expect(third.count == 2)
    }
}
