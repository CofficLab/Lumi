import Foundation
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct CPUHistoryServiceTests {
    @Test
    func recordDataPointAppendsToRecentHistory() {
        let svc = CPUHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_cpu_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        svc.recordDataPoint(usage: 45.0)
        #expect(svc.recentHistory.count == 1)
        #expect(svc.recentHistory[0].usage == 45.0)
    }

    @Test
    func recentHistoryIsCapped() {
        let svc = CPUHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_cpu_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        for i in 0..<3605 {
            svc.recordDataPoint(usage: Double(i % 100))
        }
        #expect(svc.recentHistory.count <= 3600)
    }

    @Test
    func getDataForHour1() {
        let svc = CPUHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_cpu_history_\(UUID().uuidString).json"))
        let now = Date().timeIntervalSince1970
        svc.recentHistory = [
            CPUDataPoint(timestamp: now - 100, usage: 30),
            CPUDataPoint(timestamp: now - 50, usage: 60),
        ]
        let data = svc.getData(for: .hour1)
        #expect(data.count == 2)
    }
}
