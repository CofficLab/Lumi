import Foundation
import Testing
@testable import PluginDiskSpeedTest

@Suite("DiskSpeedTester")
struct DiskSpeedTesterTests {

    /// 小数据量测速正常完成，取消检查不得误伤正常路径。
    @Test func smallMeasurementCompletes() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tester = DiskSpeedTester()

        let result = try await tester.measure(in: directory, testBytes: 2 * 1024 * 1024)

        #expect(result.write.bytes == 2 * 1024 * 1024)
        #expect(result.read.bytes == 2 * 1024 * 1024)
        #expect(result.write.bytesPerSecond > 0)
        #expect(result.read.bytesPerSecond > 0)
    }

    /// #1230：已取消的任务不得继续写入，也不得留下临时文件。
    @Test func preCancelledTaskThrowsWithoutWriting() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tester = DiskSpeedTester()

        let task = Task {
            try await tester.measure(in: directory, testBytes: 8 * 1024 * 1024 * 1024)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(leftovers.isEmpty)
    }

    /// #1230：写入中途取消必须及时中断剩余写入与后续 fsync/读取，
    /// 而不是把 8 GB 全量跑完。
    @Test func cancellationDuringWriteStopsPromptly() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tester = DiskSpeedTester()
        let startedAt = Date()

        let task = Task {
            try await tester.measure(in: directory, testBytes: 8 * 1024 * 1024 * 1024)
        }

        // 等临时文件出现（写入已经开始）再取消，构造「写入中途」的交错。
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            if !files.isEmpty { break }
            await Task.yield()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Date().timeIntervalSince(startedAt) < 10, "取消没有及时中断剩余写入")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(leftovers.isEmpty)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskSpeedTesterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}