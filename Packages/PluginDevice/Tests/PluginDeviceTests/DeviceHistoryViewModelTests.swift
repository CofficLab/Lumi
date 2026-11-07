import Foundation
import Testing
@testable import PluginDevice

/// 历史视图模型按时间范围裁剪数据的行为。
@Suite("DeviceHistoryViewModel")
@MainActor
struct DeviceHistoryViewModelTests {

    @Test("1 小时范围取高频缓冲并剔除过期样本")
    func oneHourRangeUsesHighResolutionBuffer() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [
                CPUDataPoint(timestamp: now - 60, usage: 10),
                CPUDataPoint(timestamp: now - 7200, usage: 20),
            ],
            longTerm: []
        )

        let points = viewModel.data(for: CPUTimeRange.hour1)

        #expect(points.count == 1)
        #expect(points.first?.usage == 10)
    }

    @Test("4 小时范围剔除超出范围的长期样本")
    func fourHourRangeTrimsLongTermBuffer() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [],
            longTerm: [
                CPUDataPoint(timestamp: now - 3600, usage: 30),
                CPUDataPoint(timestamp: now - 14401, usage: 40),
            ]
        )

        let points = viewModel.data(for: CPUTimeRange.hour4)

        #expect(points.count == 1)
        #expect(points.first?.usage == 30)
    }

    @Test("24 小时与 30 天范围返回不同的数据量")
    func differentLongRangesReturnDifferentData() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [],
            longTerm: [
                CPUDataPoint(timestamp: now - 3600, usage: 30),
                CPUDataPoint(timestamp: now - 43200, usage: 40),
                CPUDataPoint(timestamp: now - 86401, usage: 50),
            ]
        )

        let day = viewModel.data(for: CPUTimeRange.hour24)
        let month = viewModel.data(for: CPUTimeRange.month1)

        #expect(day.count == 2)
        #expect(month.count == 3)
        #expect(day.count != month.count)
    }

    @Test("内存历史同样按范围裁剪")
    func memoryHistoryTrimsByRange() {
        let viewModel = DeviceHistoryViewModel<MemoryDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [],
            longTerm: [
                MemoryDataPoint(timestamp: now - 60, usagePercentage: 55, usedBytes: 100),
                MemoryDataPoint(timestamp: now - 20000, usagePercentage: 45, usedBytes: 200),
            ]
        )

        let fourHours = viewModel.data(for: MemoryTimeRange.hour4)
        let oneDay = viewModel.data(for: MemoryTimeRange.hour24)

        #expect(fourHours.count == 1)
        #expect(fourHours.first?.usagePercentage == 55)
        #expect(oneDay.count == 2)
    }
}
