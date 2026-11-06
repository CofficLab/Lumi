import Foundation
import ProviderMessage
import SQLite3
import Testing
@testable import PluginMessageManager

/// 消息库「按会话取全部消息」的规模基准。
///
/// ## 背景
///
/// UI 列表走分页（`fetchMessagePage`，`pageSize=40`），是安全的。
/// 但 LLM 回合走的是另一条路径：
///
/// ```
/// AgentLoop → prepareContext → llmHistory
///           → messagesForLLM → MessageManager.readSnapshot
///           → MessageStore.fetchMessages(conversationId)   ← 无 limit
/// ```
///
/// `fetchMessages` **没有分页、没有 limit**，每次发送消息都会把整个会话的
/// 全部消息物化进内存（正文 + toolCalls + reasoning）。
///
/// 上下文压缩（`LLMContextProvider` 的滚动摘要）只能减少「发给模型的体积」，
/// 但压缩的前提是「先拿到完整历史」——所以压缩**省不掉**这笔全量物化。
///
/// ## 为什么不断言耗时
///
/// 耗时会随机器负载、磁盘与并发测试而抖动（本套件并发跑时同一逻辑的耗时
/// 能在 0.29s ~ 0.57s 之间波动）。所以耗时只作为**趋势数据**打印，
/// 断言的是**确定性的事实**：全量路径取到的条数等于该会话总条数，
/// 分页路径只取一页。
@MainActor
@Suite("MessageStore 全量物化路径基准")
struct MessageStoreFullMaterializationBenchmarks {

    /// 生产库副本路径（由环境变量指定），不存在时跳过。
    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_MESSAGES_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 复制生产库到临时目录，保证测试不污染真实数据。
    private func makeStoreFromProductionCopy() throws -> (store: MessageStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreBench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: source,
            to: directory.appendingPathComponent("messages.sqlite")
        )
        let wal = source.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: wal.path) {
            try? FileManager.default.copyItem(
                at: wal,
                to: directory.appendingPathComponent("messages.sqlite-wal")
            )
        }
        let store = try MessageStore(databaseRootURL: directory)
        return (store, directory)
    }

    @Test("全量路径取到整个会话，分页路径只取一页")
    func fullPathTakesEverythingWhilePagingTakesOnePage() throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("BENCH skip=生产库副本不可用（未设置 LUMI_PROD_MESSAGES_SQLITE）")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("messages.sqlite")
        let busiest = try findBusiestConversation(in: databaseURL)
        guard let busiest else {
            print("BENCH skip=生产库为空")
            return
        }

        let conversationID = try #require(UUID(uuidString: busiest.id))
        print("BENCH busiestConversation=\(busiest.id) messages=\(busiest.count) contentChars=\(busiest.contentChars)")

        // ── 路径 A：LLM 回合走的全量物化（fetchMessages，无 limit）──
        let fullStart = Date()
        let full = store.fetchMessages(conversationId: conversationID)
        let fullElapsed = Date().timeIntervalSince(fullStart)
        let fullChars = full.reduce(0) { $0 + $1.content.count }

        // ── 路径 B：UI 列表走的分页（fetchMessagePage，limit=40）──
        let pageStart = Date()
        let page = store.fetchMessagePage(
            conversationId: conversationID,
            limit: 40,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        let pageElapsed = Date().timeIntervalSince(pageStart)

        print("BENCH fullMaterialization messages=\(full.count) chars=\(fullChars) elapsed=\(String(format: "%.4f", fullElapsed))s")
        print("BENCH paginated messages=\(page.count) elapsed=\(String(format: "%.4f", pageElapsed))s")
        print("BENCH ratio=\(String(format: "%.1f", fullElapsed / max(pageElapsed, 0.0001)))x")

        // 证据 1：全量路径确实把整个会话搬进了内存。
        #expect(full.count == busiest.count, "全量物化条数应等于该会话总条数")
        // 证据 2：分页路径只取一页 —— 这正是 UI 列表安全的原因。
        #expect(page.count <= 40, "分页路径应只取一页，实际 \(page.count)")
        #expect(page.count < full.count, "分页应远少于全量：\(page.count) vs \(full.count)")
    }

    @Test("全量路径的物化量随会话长度增长")
    func fullPathScalesWithConversationLength() throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("BENCH scale skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("messages.sqlite")
        let buckets = try conversationBuckets(in: databaseURL)
        guard buckets.count >= 2 else {
            print("BENCH scale skip=可用会话不足")
            return
        }

        // 取「较短」和「最长」两个会话做对照。
        let sorted = buckets.sorted { $0.count < $1.count }
        let shortest = sorted[0]
        let longest = sorted[sorted.count - 1]

        var counts: [Int] = []
        var timings: [TimeInterval] = []
        for bucket in [shortest, longest] {
            let conversationID = try #require(UUID(uuidString: bucket.id))
            let start = Date()
            let messages = store.fetchMessages(conversationId: conversationID)
            let elapsed = Date().timeIntervalSince(start)
            counts.append(messages.count)
            timings.append(elapsed)
            print("BENCH scale messages=\(messages.count) elapsed=\(String(format: "%.4f", elapsed))s")
        }

        // 证据：全量路径的**物化条数**随会话长度增长 —— 这是会话级的线性开销，
        // 而不是与数据量无关的固定开销。
        #expect(
            counts[1] > counts[0],
            "更长会话应物化更多消息：\(counts)"
        )
        let growthRatio = timings[1] / max(timings[0], 0.0001)
        let sizeRatio = Double(counts[1]) / max(Double(counts[0]), 1)
        print("BENCH scale growthRatio=\(String(format: "%.2f", growthRatio))x sizeRatio=\(String(format: "%.2f", sizeRatio))x")
    }

    // MARK: - SQLite 辅助

    private struct ConversationBucket {
        let id: String
        let count: Int
        let contentChars: Int
    }

    /// 直读 SQLite 统计每个会话的条数与正文字符数（不经过 SwiftData）。
    private func conversationBuckets(in databaseURL: URL) throws -> [ConversationBucket] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return [] }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        SELECT ZCONVERSATIONID, COUNT(*), COALESCE(SUM(LENGTH(ZCONTENT)), 0) \
        FROM ZMESSAGEMODEL GROUP BY ZCONVERSATIONID
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var buckets: [ConversationBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idPointer = sqlite3_column_text(statement, 0) else { continue }
            buckets.append(ConversationBucket(
                id: String(cString: idPointer),
                count: Int(sqlite3_column_int(statement, 1)),
                contentChars: Int(sqlite3_column_int(statement, 2))
            ))
        }
        return buckets
    }

    private func findBusiestConversation(in databaseURL: URL) throws -> ConversationBucket? {
        try conversationBuckets(in: databaseURL).max { $0.count < $1.count }
    }
}
