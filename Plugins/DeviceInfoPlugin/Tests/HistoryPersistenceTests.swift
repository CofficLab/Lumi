import Foundation
import Testing
@testable import DeviceInfoPlugin

// MARK: - CPU History Persistence

@MainActor
struct CPUHistoryPersistenceTests {
    @Test
    func saveAndLoadHistory() async throws {
        let url = URL(fileURLWithPath: "/tmp/test_cpu_persistence_\(UUID().uuidString).json")
        let svc = CPUHistoryService(storageFileURL: url)

        let now = Date().timeIntervalSince1970
        svc.longTermHistory = [
            CPUDataPoint(timestamp: now - 100, usage: 30),
            CPUDataPoint(timestamp: now - 50, usage: 60),
        ]
        let task = svc.saveHistory()
        let saved = await task?.value
        #expect(saved == true)

        // Load in a new instance
        let svc2 = CPUHistoryService(storageFileURL: url)
        #expect(svc2.longTermHistory.count == 2)
        #expect(svc2.longTermHistory[0].usage == 30)
        #expect(svc2.longTermHistory[1].usage == 60)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - GPU History Persistence

@MainActor
struct GPUHistoryPersistenceTests {
    @Test
    func saveAndLoadHistory() async throws {
        let url = URL(fileURLWithPath: "/tmp/test_gpu_persistence_\(UUID().uuidString).json")
        let svc = GPUHistoryService(storageFileURL: url)

        let now = Date().timeIntervalSince1970
        svc.longTermHistory = [
            GPUDataPoint(timestamp: now - 100, usage: 25),
            GPUDataPoint(timestamp: now - 50, usage: 75),
        ]
        let task = svc.saveHistory()
        let saved = await task?.value
        #expect(saved == true)

        let svc2 = GPUHistoryService(storageFileURL: url)
        #expect(svc2.longTermHistory.count == 2)
        #expect(svc2.longTermHistory[0].usage == 25)
        #expect(svc2.longTermHistory[1].usage == 75)

        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Memory History Persistence

@MainActor
struct MemoryHistoryPersistenceTests {
    @Test
    func saveAndLoadHistory() async throws {
        let url = URL(fileURLWithPath: "/tmp/test_mem_persistence_\(UUID().uuidString).json")
        let svc = MemoryHistoryService(storageFileURL: url)

        let now = Date().timeIntervalSince1970
        svc.longTermHistory = [
            MemoryDataPoint(timestamp: now - 100, usagePercentage: 40, usedBytes: 6_000_000_000),
            MemoryDataPoint(timestamp: now - 50, usagePercentage: 65, usedBytes: 10_000_000_000),
        ]
        let task = svc.saveHistory()
        let saved = await task?.value
        #expect(saved == true)

        let svc2 = MemoryHistoryService(storageFileURL: url)
        #expect(svc2.longTermHistory.count == 2)
        #expect(svc2.longTermHistory[0].usagePercentage == 40)
        #expect(svc2.longTermHistory[1].usagePercentage == 65)

        try? FileManager.default.removeItem(at: url)
    }
}
