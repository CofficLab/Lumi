import Foundation
import Testing
@testable import PluginFileLog

/// #129 回归测试：轮询参数与去重集合的行为约束。
///
/// 背景：issue #129 报告 FileLogCoordinator 的 OSLogStore 轮询把 logd 拖到
/// 60-80% CPU。实测确认每次 `getEntries` 是 logd 侧 XPC 往返的**固定 ~2s 延迟**
/// （读 0 条与读 1110 条成本相同），因此占用率 = `3600 / 轮询间隔 × 2 / 3600`：
///
/// | 间隔 | 每小时 XPC | logd 占用 |
/// |------|------|------|
/// | 2s（修复前） | 1800 | 100% |
/// | 15s（修复后） | 240 | 13% |
///
/// 同时修正了 `writeDelay` 的语义：它本意是「等日志在 logd 里落稳再读」，
/// 属于读取阶段；此前却被同时用于「读窗口起点」和「写盘 cutoff」，
/// 导致每条日志额外多等一轮（实测落盘延迟 6.86s）且 pending 持续积压。
@Suite("FileLogCoordinator 轮询参数")
struct FileLogCoordinatorPollingTests {

    /// 反射读取私有存储属性，避免为测试放宽访问级别。
    private func storedTimeInterval(
        _ coordinator: FileLogCoordinator,
        _ label: String
    ) -> TimeInterval? {
        Mirror(reflecting: coordinator).children
            .first { $0.label == label }?
            .value as? TimeInterval
    }

    @Test("默认轮询间隔为 15 秒")
    func defaultPollIntervalIsFifteenSeconds() {
        let coordinator = FileLogCoordinator(
            logsDirectory: FileManager.default.temporaryDirectory
        )
        #expect(storedTimeInterval(coordinator, "pollInterval") == 15.0)
    }

    @Test("默认写入延迟为 1 秒")
    func defaultWriteDelayIsOneSecond() {
        let coordinator = FileLogCoordinator(
            logsDirectory: FileManager.default.temporaryDirectory
        )
        #expect(storedTimeInterval(coordinator, "writeDelay") == 1.0)
    }

    @Test("轮询间隔不再导致 logd 100% 占用")
    func pollIntervalKeepsLogdLoadReasonable() {
        let coordinator = FileLogCoordinator(
            logsDirectory: FileManager.default.temporaryDirectory
        )
        guard let interval = storedTimeInterval(coordinator, "pollInterval") else {
            Issue.record("无法读取 pollInterval")
            return
        }

        // 每次 getEntries 的固定 XPC 成本（实测值）。
        let xpcCostPerCall: TimeInterval = 2.0
        let hourlyCalls = 3600.0 / interval
        let logdLoadRatio = hourlyCalls * xpcCostPerCall / 3600.0

        // 修复前为 2s 间隔 => 占用率 100%；修复后应低于 20%。
        #expect(logdLoadRatio < 0.2)
    }

    @Test("去重集合有容量上界，不会无界增长")
    func seenRecordKeysAreBounded() {
        let capacity = FileLogCoordinator.seenRecordKeysCapacity

        // 容量必须是有限值且足够大（远大于单次轮询可能读到的条数）。
        #expect(capacity > 0)
        #expect(capacity <= 100_000)
    }
}

/// 去重集合裁剪逻辑的行为验证。
@Suite("FileLogCoordinator 去重集合裁剪")
struct FileLogCoordinatorDeduplicationTests {

    /// 复刻协调器内部的裁剪逻辑，验证 FIFO 淘汰行为。
    private struct BoundedKeySet {
        private(set) var keys: Set<String> = []
        private var order: [String] = []
        let capacity: Int

        mutating func insert(_ key: String) {
            guard keys.insert(key).inserted else { return }
            order.append(key)
            trim()
        }

        mutating func trim() {
            guard order.count > capacity else { return }
            let overflow = order.count - capacity
            for key in order.prefix(overflow) {
                keys.remove(key)
            }
            order.removeFirst(overflow)
        }
    }

    @Test("超出容量时按 FIFO 淘汰最旧的键")
    func evictsOldestKeysFirst() {
        var set = BoundedKeySet(capacity: 3)
        for i in 0..<5 { set.insert("key\(i)") }

        #expect(set.keys.count == 3)
        #expect(!set.keys.contains("key0"))
        #expect(!set.keys.contains("key1"))
        #expect(set.keys.contains("key4"))
    }

    @Test("重复插入不增加容量占用")
    func duplicateInsertDoesNotGrow() {
        var set = BoundedKeySet(capacity: 10)
        for _ in 0..<100 { set.insert("same") }
        #expect(set.keys.count == 1)
    }

    @Test("容量内不发生淘汰")
    func keepsAllKeysWithinCapacity() {
        var set = BoundedKeySet(capacity: 10)
        for i in 0..<10 { set.insert("key\(i)") }
        #expect(set.keys.count == 10)
        #expect(set.keys.contains("key0"))
    }
}

/// 写盘 cutoff 语义：不再因 `writeDelay` 而额外延后一轮。
@Suite("FileLogCoordinator 写盘 cutoff")
struct FileLogCoordinatorWriteCutoffTests {

    @Test("读到的日志立即满足写盘条件（cutoff 为当前时刻）")
    func polledRecordsAreImmediatelyWritable() {
        // 复刻修复后的语义：cutoff = pollDate，读到的记录产生时刻必然早于 pollDate。
        let pollDate = Date()
        let recordDate = pollDate.addingTimeInterval(-1.0)

        let record = FileLogCoordinator.LogRecord(
            date: recordDate,
            key: "k",
            line: "line"
        )
        let result = FileLogCoordinator.recordsReadyToWrite([record], upTo: pollDate)

        #expect(result.ready.count == 1)
        #expect(result.pending.isEmpty)
    }

    @Test("修复前的双重滞后语义会留下一条 pending（回归对照）")
    func legacyCutoffLeavesRecordPending() {
        // 修复前的 cutoff = pollDate - writeDelay(3s)，会让刚读到的记录滞留一轮。
        let pollDate = Date()
        let writeDelay: TimeInterval = 3.0
        let recordDate = pollDate.addingTimeInterval(-1.0)

        let record = FileLogCoordinator.LogRecord(
            date: recordDate,
            key: "k",
            line: "line"
        )
        let legacyResult = FileLogCoordinator.recordsReadyToWrite(
            [record],
            upTo: pollDate.addingTimeInterval(-writeDelay)
        )

        // 这正是修复前 pending 持续积压的成因。
        #expect(legacyResult.ready.isEmpty)
        #expect(legacyResult.pending.count == 1)
    }
}
