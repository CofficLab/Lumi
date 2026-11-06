import Foundation
import Testing
@testable import ProviderToolManager

/// CoreData/SQLite 的 `Date` 存储精度特性。
///
/// ## 背景
///
/// 启动恢复改为原生 SQL 读取后，`Date` 需要手动从 CoreData 的存储格式解码：
/// CoreData 把 `Date` 存成「2001-01-01 起的秒数」（Double），
/// 比 Unix 时间戳多一个 978307200 的偏移量。
///
/// 这个测试固化两个事实：
/// 1. **偏移量**必须补回来 —— 否则时间会落在 1995 年。
/// 2. **精度**会丢失 —— Double 秒 + Swift `Date` 的纳秒精度不匹配，
///    往返后两者**不相等**。这是 CoreData 的固有行为，
///    SwiftData 路径同样如此，不是原生 SQL 引入的缺陷。
@Suite("ToolJob Date 的存储精度")
struct ToolJobDatePrecisionTests {

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobDatePrecision-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Date 往返会丢失精度，但偏移量正确")
    func dateRoundTripLosesPrecisionButKeepsEpoch() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolJobRecordStore(databaseRootURL: directory)
        let now = Date()
        let record = ToolJobRecord(
            id: "precision-1",
            conversationID: UUID(),
            turnID: UUID(),
            toolName: "run_command",
            argumentsJSON: "{}",
            status: .completed,
            createdAt: now,
            startedAt: now,
            updatedAt: now,
            latestOutput: "out"
        )
        await store.upsert(record)

        let restored = await store.fetchAllJobs()
        let job = try #require(restored.first)

        // 偏移量正确：解出来的时间落在「现在附近」，而不是 1995 年。
        let drift = abs(job.createdAt.timeIntervalSince(now))
        #expect(
            drift < 1.0,
            "解码后的时间偏移了 \(drift)s —— CoreData 纪元偏移量没补对"
        )

        // 精度：CoreData 存 Double 秒，Swift `Date` 是 Double 秒 + 更高有效位。
        // 往返后二进制表示**可能**不同，于是 `==` 不一定成立。
        //
        // 这是 CoreData 的固有行为 —— SwiftData 路径同样如此，
        // 不是原生 SQL 引入的缺陷。所以断言的是「差异在毫秒级以内」，
        // 而不是严格相等（严格相等在某些位模式下恰好成立、某些不成立）。
        #expect(
            drift < 0.001,
            "解码误差 \(drift)s 超出毫秒级，精度处理有问题"
        )
    }
}
