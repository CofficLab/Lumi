import Foundation
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct MemoryHistoryServiceTests {
    @Test
    func recordDataPointAppendsToRecentHistory() {
        let svc = MemoryHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_mem_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        svc.recordDataPoint(pct: 55.0, bytes: 8_000_000_000)
        #expect(svc.recentHistory.count == 1)
        #expect(svc.recentHistory[0].usagePercentage == 55.0)
        #expect(svc.recentHistory[0].usedBytes == 8_000_000_000)
    }

    @Test
    func recentHistoryIsCapped() {
        let svc = MemoryHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_mem_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        for i in 0..<3605 {
            svc.recordDataPoint(pct: Double(i % 100), bytes: UInt64(i) * 1_000_000)
        }
        #expect(svc.recentHistory.count <= 3600)
    }
}
