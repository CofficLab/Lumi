import Foundation
import Testing
@testable import PluginFileLog

/// #472 回归：停止时必须补最后一次 OSLog 读取，并等在途轮询结果落盘。
///
/// 旧实现 `stopOnQueue` 只写 pendingRecords：上一轮轮询之后产生的日志
/// 随关闭永久丢失（下次 start 把读窗口重置到当前时刻）；在途轮询的
/// 回调看到 isRunning=false 也直接丢弃结果。
@Suite(.serialized)
struct FileLogStopDrainTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogStopDrainTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func logContents(in directory: URL) throws -> String {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "log" }
        .map { try String(contentsOf: $0, encoding: .utf8) }
        .joined()
    }

    private func waitSync(_ semaphore: DispatchSemaphore) {
        semaphore.wait()
    }

    @Test("停止前补最后一次读取，未轮询到的日志不丢失")
    func stopDrainsUnpolledWindowBeforeClosing() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        // 模拟「上一轮轮询之后才产生」的日志：长间隔下定时器永远读不到它。
        coordinator.logRecordReader = { _, _ in
            [
                FileLogCoordinator.LogRecord(
                    date: Date(),
                    key: "last-window-entry",
                    line: "last window entry\n"
                )
            ]
        }

        coordinator.start()
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        #expect(contents.contains("last window entry"))
    }

    @Test("stopAndWait 等在途轮询结果落盘后才关闭文件")
    func stopAndWaitIngestsInFlightPollResults() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 0.05)

        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var firstCall = true
        let inFlightDate = Date()
        coordinator.logRecordReader = { _, _ in
            lock.lock()
            let isFirst = firstCall
            firstCall = false
            lock.unlock()
            if isFirst {
                entered.signal()
                release.wait()
                return [
                    FileLogCoordinator.LogRecord(
                        date: inFlightDate,
                        key: "in-flight-entry",
                        line: "in flight entry\n"
                    )
                ]
            }
            return [
                FileLogCoordinator.LogRecord(
                    date: inFlightDate.addingTimeInterval(1),
                    key: "tail-entry",
                    line: "tail entry\n"
                )
            ]
        }

        coordinator.start()
        // 等第一轮读取真正进入（此时 pollInFlight 为 true 且被门闩卡住）。
        await Task.detached { self.waitSync(entered) }.value
        let stopTask = Task.detached { coordinator.stopAndWait() }
        // 让 stop 先排进 queue，构造「停止发生在读取在途时」。
        try await Task.sleep(nanoseconds: 100_000_000)
        release.signal()
        await stopTask.value

        let contents = try logContents(in: directory)
        #expect(contents.contains("in flight entry"), "在途轮询结果不得因停止被丢弃")
        #expect(contents.contains("tail entry"), "停止收尾仍须补最后一次读取")
    }

    @Test("停止时的补读不重复写入已持久化的记录")
    func stopDrainDoesNotDuplicatePersistedRecords() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        let record = FileLogCoordinator.LogRecord(
            date: Date(),
            key: "already-persisted",
            line: "already persisted entry\n"
        )
        // OSLogStore 是累计读取：补读会再次返回同一条记录。
        coordinator.logRecordReader = { _, _ in [record] }

        coordinator.start()
        coordinator.ingestPolledRecords([record], pollDate: Date())
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        let occurrences = contents.components(separatedBy: "already persisted entry").count - 1
        #expect(occurrences == 1)
    }
}