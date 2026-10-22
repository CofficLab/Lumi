import Foundation
import Testing
@testable import ProviderToolManager

struct ToolCallRecordStoreTests {

    /// 每个测试使用独立临时目录，避免跨测试数据库冲突。
    private func makeStore() throws -> (ToolCallRecordStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolCallRecordStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (ToolCallRecordStore(databaseRootURL: dir), dir)
    }

    @Test("record 后按 turnID / conversationID 可查询")
    func recordAndFetch() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let turnID = UUID()
        let conversationID = UUID()
        await store.record(
            toolCallID: "call-1",
            toolName: "read_file",
            toolDisplayName: "读取文件",
            turnID: turnID,
            conversationID: conversationID,
            createdAt: Date(),
            startedAt: Date(),
            completedAt: Date(),
            duration: 0.5,
            argumentsJSON: #"{"path":"/tmp/a"}"#,
            resultContent: "content-a",
            resultIsError: false,
            riskLevel: "low"
        )

        let byTurn = await store.fetchRecords(forTurnID: turnID)
        #expect(byTurn.count == 1)
        #expect(byTurn.first?.toolName == "read_file")
        #expect(byTurn.first?.conversationID == conversationID)

        let byConversation = await store.fetchRecords(for: conversationID)
        #expect(byConversation.count == 1)

        let byCallID = await store.fetchRecord(forToolCallID: "call-1")
        #expect(byCallID?.toolDisplayName == "读取文件")
        #expect(byCallID?.duration == 0.5)
    }

    /// 批量查询必须只返回指定 turn 的记录。
    ///
    /// 谓词写错（例如 `turnID ?? ""`）时 CoreData 无法生成 SQL，运行时直接
    /// abort；谓词写得太宽则会多带出别的 turn 的记录。这条用例同时锁住
    /// 「不崩」与「过滤精确」两件事。
    @Test("批量按 turnID 查询只返回指定 turn 的记录")
    func fetchRecordsForTurnIDs() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let conversationID = UUID()
        let wantedTurn = UUID()
        let otherTurn = UUID()
        let plan: [(String, UUID?)] = [
            ("call-a1", wantedTurn),
            ("call-a2", wantedTurn),
            ("call-b1", otherTurn),
            ("call-none", nil)
        ]
        for (toolCallID, turnID) in plan {
            await store.record(
                toolCallID: toolCallID,
                toolName: "tool",
                toolDisplayName: "tool",
                turnID: turnID,
                conversationID: conversationID,
                createdAt: Date(),
                startedAt: Date(),
                completedAt: nil,
                duration: nil,
                argumentsJSON: "{}",
                resultContent: toolCallID,
                resultIsError: false,
                riskLevel: "low"
            )
        }

        let fetched = await store.fetchRecords(forTurnIDs: [wantedTurn])

        #expect(fetched.count == 2)
        #expect(Set(fetched.map(\.toolCallID)) == ["call-a1", "call-a2"])
        #expect(fetched.allSatisfy { $0.turnID == wantedTurn })
        #expect(await store.fetchRecords(forTurnIDs: []).isEmpty)
        #expect(await store.fetchRecords(forTurnIDs: [wantedTurn, otherTurn]).count == 3)
    }

    @Test("deleteAll 删除记录并阻止后续写入")
    func deleteAll() async throws {        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let conversationID = UUID()
        for index in 0..<3 {
            await store.record(
                toolCallID: "call-\(index)",
                toolName: "tool",
                toolDisplayName: "tool",
                turnID: nil,
                conversationID: conversationID,
                createdAt: Date(),
                startedAt: Date(),
                completedAt: nil,
                duration: nil,
                argumentsJSON: "{}",
                resultContent: "r\(index)",
                resultIsError: false,
                riskLevel: "safe"
            )
        }
        #expect(await store.count() == 3)

        await store.deleteAll(for: conversationID)
        #expect(await store.count() == 0)

        // 删除后的会话不再接受新记录
        await store.record(
            toolCallID: "call-late",
            toolName: "tool",
            toolDisplayName: "tool",
            turnID: nil,
            conversationID: conversationID,
            createdAt: Date(),
            startedAt: Date(),
            completedAt: nil,
            duration: nil,
            argumentsJSON: "{}",
            resultContent: "late",
            resultIsError: false,
            riskLevel: "safe"
        )
        #expect(await store.count() == 0)
    }

    @Test("count 反映持久化记录数")
    func count() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let conversationID = UUID()
        for index in 0..<5 {
            await store.record(
                toolCallID: "c\(index)",
                toolName: "tool",
                toolDisplayName: "tool",
                turnID: nil,
                conversationID: conversationID,
                createdAt: Date(),
                startedAt: Date(),
                completedAt: nil,
                duration: nil,
                argumentsJSON: "{}",
                resultContent: "r",
                resultIsError: false,
                riskLevel: "safe"
            )
        }
        #expect(await store.count() == 5)
    }
}
