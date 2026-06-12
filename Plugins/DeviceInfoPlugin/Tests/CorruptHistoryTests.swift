import Foundation
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct CorruptHistoryQuarantineTests {
    private func makeCorruptFile(serviceName: String) -> URL {
        let url = URL(fileURLWithPath: "/tmp/test_\(serviceName)_corrupt_\(UUID().uuidString).json")
        try? "this is not json".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test
    func cpuHistoryQuarantinesCorruptFile() {
        let url = makeCorruptFile(serviceName: "cpu")
        let svc = CPUHistoryService(storageFileURL: url)
        #expect(svc.longTermHistory.isEmpty)
        let quarantineURL = url.deletingLastPathComponent().appendingPathComponent("cpu_history.corrupt.json")
        #expect(FileManager.default.fileExists(atPath: quarantineURL.path))
        // Cleanup
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test
    func gpuHistoryQuarantinesCorruptFile() {
        let url = makeCorruptFile(serviceName: "gpu")
        let svc = GPUHistoryService(storageFileURL: url)
        #expect(svc.longTermHistory.isEmpty)
        let quarantineURL = url.deletingLastPathComponent().appendingPathComponent("gpu_history.corrupt.json")
        #expect(FileManager.default.fileExists(atPath: quarantineURL.path))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test
    func memoryHistoryQuarantinesCorruptFile() {
        let url = makeCorruptFile(serviceName: "memory")
        let svc = MemoryHistoryService(storageFileURL: url)
        #expect(svc.longTermHistory.isEmpty)
        let quarantineURL = url.deletingLastPathComponent().appendingPathComponent("memory_history.corrupt.json")
        #expect(FileManager.default.fileExists(atPath: quarantineURL.path))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
