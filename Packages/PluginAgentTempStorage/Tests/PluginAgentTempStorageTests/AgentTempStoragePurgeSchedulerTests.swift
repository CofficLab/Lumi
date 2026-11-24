import Foundation
import Testing
@testable import PluginAgentTempStorage

@MainActor
struct ExpiredTempFilePurgeSchedulerTests {
    /// 回归 #509：过期文件必须由启动/定时清理删除，而不是只依赖
    /// 下一次 Agent 工具调用顺带触发。
    @Test
    func schedulerPurgesExpiredFilesWithoutAnyToolCall() async throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        let path = try await service.write(filename: "stale.md", content: "stale")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)],
            ofItemAtPath: path
        )

        let scheduler = ExpiredTempFilePurgeScheduler(interval: .seconds(3600)) {
            try await service.purgeExpiredFiles()
        }
        scheduler.start()
        defer { scheduler.stop() }

        // 启动即清理：轮询等待过期文件消失，不依赖任何工具调用。
        for _ in 0..<200 where FileManager.default.fileExists(atPath: path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(FileManager.default.fileExists(atPath: path) == false)
        #expect(try await service.listFiles().isEmpty)
    }

    /// 回归 #509：调度按周期重复，stop 后不再继续清理。
    @Test
    func stopCancelsScheduledPurges() async throws {
        actor PurgeCounter {
            var count = 0
            func bump() { count += 1 }
        }
        let counter = PurgeCounter()
        let scheduler = ExpiredTempFilePurgeScheduler(interval: .milliseconds(30)) {
            await counter.bump()
        }

        scheduler.start()
        // 启动清理 1 次 + 周期清理若干次。
        try await Task.sleep(for: .milliseconds(250))
        let countBeforeStop = await counter.count
        #expect(countBeforeStop >= 2)

        scheduler.stop()
        try await Task.sleep(for: .milliseconds(150))
        let countAfterStop = await counter.count
        // 取消传播前最多再完成一次已开始的清理。
        #expect(countAfterStop <= countBeforeStop + 1)
        #expect(countAfterStop >= countBeforeStop)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExpiredTempFilePurgeSchedulerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
