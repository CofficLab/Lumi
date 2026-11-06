import Foundation
import KitAgentTool
import Testing
@testable import ProviderToolManager

/// 启动恢复路径的红测试：恢复**不得**把终态 Job 的 `resultJSON` 搬进内存。
///
/// ## 要复现的问题
///
/// `tool_jobs.sqlite` 随使用单调增长（生产库实测 49530 条 / 跨度 49.9 天），
/// 且**没有任何保留策略**——终态 Job 只在删除对应会话时才被清理。
///
/// 启动时 `ToolExecutionManager.attachJobRecordStore(_:)` 调用
/// `fetchAllJobs()`，它**没有 limit**，把库里每一条 Job 全部物化，并逐条
/// `value()` 解码 `resultJSON`（生产库合计 233MB，单条最大 3.9MB）。
///
/// 实测启动恢复耗时随 Job 总量线性增长，**没有天花板**：
///
/// ```
/// kept=1000  elapsed=0.12s
/// kept=5000  elapsed=1.41s
/// kept=20000 elapsed=3.80s
/// kept=49000 elapsed=7.67s      ← 49 天使用即如此
/// ```
///
/// ## 为什么不能靠「只恢复非终态」解决
///
/// `isTerminal` 是 `ToolJobStatus` 的**计算属性**，SwiftData 的 `#Predicate`
/// 无法把它下推到 SQL。实测 `fetchNonTerminalJobs()` 只比 `fetchAllJobs()`
/// 快约 1.2 倍 —— 49530 行**全部**被物化，每行的 `resultJSON` 也都被
/// JSON 解码过一遍，然后才丢掉 99.8%。
///
/// 同理，`propertiesToFetch` 只快 1.3 倍：它只影响 SwiftData 的 faulting
/// 行为，不改变 SQLite 实际读取的行数据。
///
/// **唯一有效的手段是让 SQL 层少返回行、少返回大字段。**
///
/// ## 这个测试断言的不变式
///
/// 终态 Job 的 `result` **可以不在启动时物化** —— 它在 `tool_calls.sqlite`
/// 里另有一份（`ToolCallRecordStore`），可以按需查询。
///
/// 但终态 Job 的**身份与状态**必须完整恢复 —— `ToolExecutionManager.submit`
/// 依赖 `jobsByID` 做幂等检查（同 conversationID + turnID + toolCall.id
/// 不重复执行），`ToolJobPersistenceTests` 也断言重启后能取回终态 Job。
@Suite("ToolJob 启动恢复的物化上限")
struct ToolJobStartupMaterializationTests {

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobStartupMaterialization-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 造一条终态 Job，携带一个明显的「大结果」。
    private func makeTerminalRecord(
        id: String,
        conversationID: UUID,
        resultContent: String
    ) -> ToolJobRecord {
        let now = Date()
        return ToolJobRecord(
            id: id,
            toolCallID: "call-\(id)",
            conversationID: conversationID,
            turnID: UUID(),
            toolName: "run_command",
            argumentsJSON: #"{"command":"echo hi"}"#,
            argumentsHash: ToolJobRecord.makeArgumentsHash(#"{"command":"echo hi"}"#),
            status: .completed,
            createdAt: now,
            startedAt: now,
            updatedAt: now,
            latestOutput: "output",
            outputByteCount: 6,
            result: ToolCallResult(content: resultContent),
            errorMessage: nil
        )
    }

    @Test("启动恢复不得物化终态 Job 的 resultJSON")
    func startupRestoreMustNotMaterializeTerminalResults() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolJobRecordStore(databaseRootURL: directory)
        let conversationID = UUID()

        // 造 200 条终态 Job，每条携带 64KB 的结果 —— 合计约 12MB。
        let largeResult = String(repeating: "x", count: 64 * 1024)
        for index in 0..<200 {
            await store.upsert(makeTerminalRecord(
                id: "job-\(index)",
                conversationID: conversationID,
                resultContent: largeResult
            ))
        }

        // 启动恢复实际走的路径。
        let restored = await store.fetchAllJobs()

        #expect(restored.count == 200, "恢复的 Job 条数不应改变")

        // ── 不变式：终态 Job 的结果不得在启动时被物化 ──
        //
        // 理由：终态 Job 的结果在 `tool_calls.sqlite` 里另有一份，可以按需查。
        // 启动恢复只需要「身份 + 状态」来维持幂等索引。
        let carriedResults = restored.compactMap(\.result)
        #expect(
            carriedResults.isEmpty,
            """
            启动恢复物化了 \(carriedResults.count)/\(restored.count) 条终态 Job 的结果，\
            每个约 64KB。这些大字段是启动开销的主要来源（生产库合计 233MB）。\
            终态 Job 的结果应改为按需读取。
            """
        )
    }

    @Test("启动恢复必须完整保留终态 Job 的身份与状态")
    func startupRestoreMustKeepIdentityAndStatus() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolJobRecordStore(databaseRootURL: directory)
        let conversationID = UUID()
        let record = makeTerminalRecord(
            id: "job-identity",
            conversationID: conversationID,
            resultContent: "done"
        )
        await store.upsert(record)

        let restored = await store.fetchAllJobs()
        let job = try #require(restored.first)

        // 幂等索引依赖这些字段，一个都不能丢。
        #expect(job.id == record.id)
        #expect(job.toolCallID == record.toolCallID)
        #expect(job.conversationID == record.conversationID)
        #expect(job.turnID == record.turnID)
        #expect(job.toolName == record.toolName)
        #expect(job.argumentsJSON == record.argumentsJSON)
        #expect(job.status == .completed)
        // CoreData 把 `Date` 存成 Double 秒，往返后二进制表示可能不同，
        // 所以用容差而不是严格相等。精度特性见 `ToolJobDatePrecisionTests`。
        #expect(
            abs(job.createdAt.timeIntervalSince(record.createdAt)) < 0.001,
            "createdAt 偏差过大：\(job.createdAt.timeIntervalSince(record.createdAt))s"
        )
        #expect(job.completedAt == record.completedAt)
        #expect(job.latestOutput == record.latestOutput)
    }

    @Test("非终态 Job 必须完整恢复（含结果）")
    func nonTerminalJobsMustKeepResult() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolJobRecordStore(databaseRootURL: directory)
        let conversationID = UUID()
        let now = Date()
        let record = ToolJobRecord(
            id: "job-running",
            toolCallID: "call-running",
            conversationID: conversationID,
            turnID: UUID(),
            toolName: "run_command",
            argumentsJSON: "{}",
            argumentsHash: "hash",
            status: .running,
            createdAt: now,
            startedAt: now,
            updatedAt: now,
            latestOutput: "partial",
            outputByteCount: 7,
            result: ToolCallResult(content: "still running"),
            errorMessage: nil
        )
        await store.upsert(record)

        let restored = await store.fetchAllJobs()
        let job = try #require(restored.first)

        // 非终态 Job 数量极少（生产库 82/49530），全量恢复它们没有成本问题，
        // 而且 `restore` 会用它们构造「无法恢复」的失败结果 —— 必须完整。
        #expect(job.status == .running)
        #expect(job.result?.content == "still running")
    }
}
