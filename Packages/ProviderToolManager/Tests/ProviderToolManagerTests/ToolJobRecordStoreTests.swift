import Foundation
import KitAgentTool
import Testing
@testable import ProviderToolManager

struct ToolJobRecordStoreTests {
    private func makeStore() throws -> (ToolJobRecordStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobRecordStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (ToolJobRecordStore(databaseRootURL: directory), directory)
    }

    private func makeRecord(
        id: String,
        conversationID: UUID,
        turnID: UUID?,
        status: ToolJobStatus = .queued,
        latestOutput: String = "",
        result: ToolCallResult? = nil
    ) -> ToolJobRecord {
        let argumentsJSON = #"{"path":"/tmp/example.txt"}"#
        let now = Date()
        return ToolJobRecord(
            id: id,
            conversationID: conversationID,
            turnID: turnID,
            toolName: "read_file",
            argumentsJSON: argumentsJSON,
            argumentsHash: ToolJobRecord.makeArgumentsHash(argumentsJSON),
            status: status,
            createdAt: now,
            startedAt: status == .queued ? nil : now,
            updatedAt: now,
            latestOutput: latestOutput,
            outputByteCount: latestOutput.utf8.count,
            completedAt: status.isTerminal ? now : nil,
            result: result
        )
    }

    @Test("Job Store 支持创建、更新、终态查询和结果持久化")
    func upsertAndFetchLifecycle() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let turnID = UUID()
        let queued = makeRecord(id: "job-1", conversationID: conversationID, turnID: turnID)
        await store.upsert(queued)

        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("tool_jobs.sqlite").path
        ))
        #expect(await store.fetchRecord(forJobID: "job-1") == queued)
        #expect(await store.fetchNonTerminalJobs().map(\.id) == ["job-1"])

        let result = ToolCallResult(content: "file content")
        var completed = queued
        completed.status = .completed
        completed.startedAt = queued.createdAt
        completed.updatedAt = Date()
        completed.completedAt = completed.updatedAt
        completed.latestOutput = "tail"
        completed.outputByteCount = completed.latestOutput.utf8.count
        completed.result = result
        await store.upsert(completed)

        let fetched = await store.fetchRecord(forJobID: "job-1")
        #expect(fetched?.status == .completed)
        #expect(fetched?.latestOutput == "tail")
        #expect(fetched?.result == result)
        #expect(await store.fetchNonTerminalJobs().isEmpty)
    }

    @Test("Job Store 支持按会话/回合查询和删除")
    func queryAndDeleteByScope() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstConversation = UUID()
        let secondConversation = UUID()
        let turnID = UUID()
        await store.upsert(makeRecord(id: "job-a", conversationID: firstConversation, turnID: turnID))
        await store.upsert(makeRecord(id: "job-b", conversationID: firstConversation, turnID: nil))
        await store.upsert(makeRecord(id: "job-c", conversationID: secondConversation, turnID: turnID))

        #expect(await store.fetchJobs(forConversationID: firstConversation).map(\.id) == ["job-a", "job-b"])
        #expect(await store.fetchJobs(forTurnID: turnID).map(\.id) == ["job-a", "job-c"])

        await store.deleteAll(for: firstConversation)
        #expect(await store.fetchJobs(forConversationID: firstConversation).isEmpty)
        #expect(await store.fetchRecord(forJobID: "job-c") != nil)
    }

    @Test("Job Store 输出尾部保持在 64 KiB 以内")
    func outputIsBounded() {
        let output = String(repeating: "x", count: 70 * 1024)
        let bounded = ToolJobRecordStore.boundedOutput(output)
        #expect(bounded.utf8.count == 64 * 1024)
        #expect(bounded == String(output.suffix(64 * 1024)))
    }
}
