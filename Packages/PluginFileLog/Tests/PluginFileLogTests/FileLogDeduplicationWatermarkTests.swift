import Foundation
import Testing
@testable import PluginFileLog

/// #927 回归测试：OSLogStore 的读取是累计的，去重集合淘汰旧 key 后不能把旧日志再写一次。
///
/// `position(date:)` 实测不限制读取范围（见
/// `docs/project-filelog-first-principles.md`：10→20→30→40 条累计返回），
/// 因此仅靠最多 20,000 个 key 的集合去重，一旦淘汰就会在下一轮把同一条
/// 历史日志当成新记录追加，形成每轮重复写一条旧日志的级联。
@Suite(.serialized)
struct FileLogDeduplicationWatermarkTests {

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogDedupTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func logContents(in directory: URL) throws -> String {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "log" }
        return try files
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined()
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func makeRecords(
        count: Int,
        startDate: Date,
        linePrefix: String = "record"
    ) -> [FileLogCoordinator.LogRecord] {
        (0..<count).map { index in
            FileLogCoordinator.LogRecord(
                date: startDate.addingTimeInterval(TimeInterval(index)),
                key: "\(linePrefix)-key-\(index)",
                line: "\(linePrefix)-\(index)\n"
            )
        }
    }

    @Test("去重集合淘汰旧 key 后，累计读取不会再写一次旧日志")
    func evictedKeysAreNotRewrittenByCumulativeReads() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // 比容量多一条：第一轮结束后最旧一条的 key 必然被 FIFO 淘汰。
        let records = makeRecords(count: FileLogCoordinator.seenRecordKeysCapacity + 1, startDate: base)
        let cutoff = base.addingTimeInterval(1_000_000)

        coordinator.start()
        coordinator.ingestPolledRecords(records, pollDate: cutoff)
        // 第二轮读到同一批累计历史（OSLogStore 不会按 position 裁剪），且没有新日志。
        coordinator.ingestPolledRecords(records, pollDate: cutoff)
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        #expect(occurrences(of: "record-0\n", in: contents) == 1, "被淘汰的旧日志不得重复写入")
        #expect(occurrences(of: "record-1\n", in: contents) == 1, "级联淘汰不得让第二条旧日志重复")
    }

    @Test("同一时间戳的边界记录跨轮询只写一次")
    func boundaryTimestampRecordsAreDedupedAcrossPolls() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        let boundary = Date(timeIntervalSinceReferenceDate: 1_000)
        let records = (0..<3).map { index in
            FileLogCoordinator.LogRecord(
                date: boundary,
                key: "boundary-\(index)",
                line: "boundary-\(index)\n"
            )
        }

        coordinator.start()
        coordinator.ingestPolledRecords(records, pollDate: boundary.addingTimeInterval(60))
        coordinator.ingestPolledRecords(records, pollDate: boundary.addingTimeInterval(120))
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        for index in 0..<3 {
            #expect(occurrences(of: "boundary-\(index)\n", in: contents) == 1)
        }
    }

    @Test("累计读取中的新记录仍然只写一次")
    func newRecordsAfterWatermarkAreWrittenExactlyOnce() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        let base = Date(timeIntervalSinceReferenceDate: 2_000)
        let firstBatch = makeRecords(count: 5, startDate: base)
        let newRecord = FileLogCoordinator.LogRecord(
            date: base.addingTimeInterval(100),
            key: "new-key",
            line: "new-record\n"
        )

        coordinator.start()
        coordinator.ingestPolledRecords(firstBatch, pollDate: base.addingTimeInterval(60))
        // 第二轮返回累计历史 + 一条新日志；第三轮没有任何新日志。
        coordinator.ingestPolledRecords(firstBatch + [newRecord], pollDate: base.addingTimeInterval(120))
        coordinator.ingestPolledRecords(firstBatch + [newRecord], pollDate: base.addingTimeInterval(180))
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        #expect(occurrences(of: "record-0\n", in: contents) == 1)
        #expect(occurrences(of: "new-record\n", in: contents) == 1)
    }

    @Test("首轮仍会收录早于启动读窗口的历史日志")
    func firstPollStillCapturesHistoryOlderThanStartWindow() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 3_600)
        let oldDate = Date(timeIntervalSinceReferenceDate: 5_000)
        let oldRecord = FileLogCoordinator.LogRecord(
            date: oldDate,
            key: "old-key",
            line: "old-record\n"
        )

        coordinator.start()
        coordinator.ingestPolledRecords([oldRecord], pollDate: Date())
        coordinator.stopAndWait()

        let contents = try logContents(in: directory)
        #expect(occurrences(of: "old-record\n", in: contents) == 1)
    }
}
