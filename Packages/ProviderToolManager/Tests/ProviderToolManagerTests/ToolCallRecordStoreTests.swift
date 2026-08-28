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

    @Test("deleteAll 删除记录并阻止后续写入")
    func deleteAll() async throws {
        let (store, dir) = try makeStore()
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
