import Foundation
import Testing
@testable import PluginDevice

/// 温度历史采集服务的缓冲与聚合行为。
@Suite("ThermalHistoryService")
@MainActor
struct ThermalHistoryServiceTests {

    @Test("采样点写入高频缓冲")
    func recordsRecentPoints() {
        let service = ThermalHistoryService()

        service.recordDataPoint(celsius: 42.5)
        service.recordDataPoint(celsius: 45.0)

        #expect(service.recentHistory.count == 2)
        #expect(service.recentHistory.last?.celsius == 45.0)
    }

    @Test("1 小时范围只保留截止时间之后的点")
    func filtersRecentByRange() {
        let service = ThermalHistoryService()
        let now = Date().timeIntervalSince1970

        service.recordDataPoint(celsius: 40.0)
        // 构造一个 2 小时前的点,模拟持久化加载后的历史数据
        service.recentHistory.append(
            ThermalDataPoint(timestamp: now - 7200, celsius: 30.0)
        )

        let oneHour = service.getData(for: .hour1)
        #expect(oneHour.count == 1)
        #expect(oneHour.first?.celsius == 40.0)
    }

    @Test("超过 1 小时的范围走分钟级聚合缓冲")
    func usesLongTermBufferForLongerRanges() {
        let service = ThermalHistoryService()
        let now = Date().timeIntervalSince1970

        service.recordDataPoint(celsius: 40.0)
        service.longTermHistory.append(
            ThermalDataPoint(timestamp: now - 7200, celsius: 30.0)
        )

        let fourHours = service.getData(for: .hour4)
        // 1 个长期点 + 当前分钟内聚合出的 1 个点
        #expect(fourHours.count == 2)
        #expect(fourHours.contains { $0.celsius == 30.0 })
    }
}
