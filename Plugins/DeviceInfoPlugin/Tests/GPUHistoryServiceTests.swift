import Foundation
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct GPUHistoryServiceTests {
    @Test
    func recordDataPointAppendsToRecentHistory() {
        let svc = GPUHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_gpu_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        svc.recordDataPoint(usage: 33.0)
        #expect(svc.recentHistory.count == 1)
        #expect(svc.recentHistory[0].usage == 33.0)
    }

    @Test
    func recentHistoryIsCapped() {
        let svc = GPUHistoryService(storageFileURL: URL(fileURLWithPath: "/tmp/test_gpu_history_\(UUID().uuidString).json"))
        svc.recentHistory = []
        for i in 0..<1805 {
            svc.recordDataPoint(usage: Double(i % 100))
        }
        #expect(svc.recentHistory.count <= 1800)
    }
}
