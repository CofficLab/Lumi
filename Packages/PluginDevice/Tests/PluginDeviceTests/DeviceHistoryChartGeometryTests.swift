import Foundation
import Testing
@testable import PluginDevice

/// 历史图表的 X 坐标按时间戳映射，而不是按数组下标等距排列。
@Suite("DeviceHistoryChartGeometry")
struct DeviceHistoryChartGeometryTests {

    @Test("X 坐标按时间戳比例映射")
    func xMapsTimestampsProportionally() {
        let x0 = DeviceHistoryChartGeometry.x(for: 0, start: 0, end: 7200, width: 200)
        let x1 = DeviceHistoryChartGeometry.x(for: 3600, start: 0, end: 7200, width: 200)
        let x2 = DeviceHistoryChartGeometry.x(for: 7200, start: 0, end: 7200, width: 200)

        #expect(x0 == 0)
        #expect(abs(x1 - 100) < 0.001)
        #expect(x2 == 200)
    }

    @Test("长时间空洞占据真实水平距离")
    func longGapKeepsProportionalWidth() {
        // 0s 与 60s 相邻，之后直接跳到 3660s：等距下标会把 60s 画在中间。
        let shortGap = DeviceHistoryChartGeometry.x(for: 60, start: 0, end: 3660, width: 100)
        #expect(abs(shortGap - 1.639) < 0.01)
    }

    @Test("超出时间范围的值被钳制在边界")
    func xClampsOutOfRangeTimestamps() {
        #expect(DeviceHistoryChartGeometry.x(for: -10, start: 0, end: 100, width: 50) == 0)
        #expect(DeviceHistoryChartGeometry.x(for: 200, start: 0, end: 100, width: 50) == 50)
        #expect(DeviceHistoryChartGeometry.x(for: 10, start: 10, end: 10, width: 50) == 0)
    }

    @Test("悬浮选点按时间轴就近命中")
    func hoverSelectsNearestTimestamp() {
        let timestamps: [TimeInterval] = [0, 60, 3660]
        // 60s 对应 x≈1.639；按下标等距会命中第 0 个点。
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 1.639, timestamps: timestamps, width: 100) == 1)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 50, timestamps: timestamps, width: 100) == 1)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 99, timestamps: timestamps, width: 100) == 2)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 0, timestamps: timestamps, width: 100) == 0)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 10, timestamps: [], width: 100) == nil)
    }
}
