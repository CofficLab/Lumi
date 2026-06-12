import Foundation
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct BatteryHistoryServiceTests {
    @Test
    func recordDataPointAppendsToRecentHistory() {
        let svc = BatteryHistoryService()
        svc.recentHistory = []
        svc.recordDataPoint(watts: 12.5)
        #expect(svc.recentHistory.count == 1)
        #expect(svc.recentHistory[0].watts == 12.5)
    }

    @Test
    func recentHistoryIsCapped() {
        let svc = BatteryHistoryService()
        svc.recentHistory = []
        for i in 0..<725 {
            svc.recordDataPoint(watts: Double(i))
        }
        #expect(svc.recentHistory.count <= 720)
    }

    @Test
    func getDataFiltersByTimeRange() {
        let svc = BatteryHistoryService()
        let now = Date().timeIntervalSince1970
        svc.recentHistory = [
            BatteryDataPoint(timestamp: now - 200, watts: 10),
            BatteryDataPoint(timestamp: now - 50, watts: 20),
        ]
        let data = svc.getData(for: .minute1)
        #expect(data.count == 1)
        #expect(data[0].watts == 20)
    }
}
