import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

private struct PersistedDelayedTool: SuperAgentTool, @unchecked Sendable {
    let name = "persisted_delay"
    let delayNanoseconds: UInt64

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return "done"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        await context.reportOutput(.stdout, "persisted-output")
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return ToolCallResult(content: "done")
    }
}

@MainActor
private func waitForRecord(
    _ store: ToolJobRecordStore,
    jobID: String,
    status: ToolJobStatus,
    attempts: Int = 40
) async -> ToolJobRecord? {
    for _ in 0..<attempts {
        if let record = await store.fetchRecord(forJobID: jobID), record.status == status {
            return record
        }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return await store.fetchRecord(forJobID: jobID)
}

struct ToolJobPersistenceTests {
    private func makeStore() throws -> (ToolJobRecordStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (ToolJobRecordStore(databaseRootURL: directory), directory)
    }

    @MainActor
    @Test("ToolExecutionManager 持久化 Job 生命周期和结果")
    func executionLifecycleIsPersisted() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ToolManager()
        manager.jobRecordStore = store
        manager.add(PersistedDelayedTool(delayNanoseconds: 80_000_000), pluginID: "test")
        let call = ToolCall(id: "persisted-1", name: "persisted_delay", arguments: "{}")

        _ = manager.submit(
            [call],
            policy: .autoExecute,
            conversationID: UUID(),
            turnID: UUID()
        )
        let result = await manager.waitForJobResult(jobID: call.id)
        let record = await waitForRecord(store, jobID: call.id, status: .completed)

        #expect(result?.content == "done")
        #expect(record?.status == .completed)
        #expect(record?.result?.content == "done")
        #expect(record?.latestOutput == "persisted-output")
        #expect(record?.argumentsHash.isEmpty == false)

        let restartedManager = ToolManager()
        restartedManager.jobRecordStore = store
        var restored: ToolJob?
        for _ in 0..<40 {
            restored = restartedManager.job(for: call.id)
            if restored?.status == .completed { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(restored?.status == .completed)

        // The restarted manager has no registered tool, so this proves the
        // terminal snapshot was reused instead of executing a new attempt.
        let reused = restartedManager.submit(
            [call],
            policy: .autoExecute,
            conversationID: UUID(),
            turnID: UUID()
        )
        #expect(reused.first?.status == .completed)
        #expect(await restartedManager.waitForJobResult(jobID: call.id) == result)
    }

    @MainActor
    @Test("启动时未完成的 Job 被安全标记为失败且不自动重跑")
    func unfinishedJobsAreSettledAfterRestart() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let now = Date()
        let record = ToolJobRecord(
            id: "orphaned-1",
            conversationID: conversationID,
            turnID: UUID(),
            toolName: "run_command",
            argumentsJSON: #"{"command":"touch /tmp/should-not-run"}"#,
            argumentsHash: ToolJobRecord.makeArgumentsHash(#"{"command":"touch /tmp/should-not-run"}"#),
            status: .running,
            createdAt: now,
            startedAt: now,
            updatedAt: now,
            latestOutput: "partial output",
            outputByteCount: 14,
            processID: 1234
        )
        await store.upsert(record)

        let manager = ToolManager()
        manager.jobRecordStore = store

        var recovered: ToolJob?
        for _ in 0..<40 {
            recovered = manager.job(for: record.id)
            if recovered?.status == .failed { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        #expect(recovered?.status == .failed)
        #expect(recovered?.latestOutput == "partial output")
        let settled = await waitForRecord(store, jobID: record.id, status: .failed)
        #expect(settled?.errorMessage?.contains("无法恢复") == true)
        #expect(settled?.result?.isError == true)
    }

    @MainActor
    @Test("删除会话会取消运行中的 Job 并阻止迟到持久化")
    func deletingConversationCancelsJobsAndClearsRecords() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ToolManager()
        manager.jobRecordStore = store
        manager.add(
            PersistedDelayedTool(delayNanoseconds: 5_000_000_000),
            pluginID: "test"
        )

        let conversationID = UUID()
        let call = ToolCall(
            id: "deleted-conversation-job",
            name: "persisted_delay",
            arguments: "{}"
        )
        _ = manager.submit(
            [call],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: UUID()
        )

        let resultTask = Task { await manager.waitForJobResult(jobID: call.id) }
        try await Task.sleep(nanoseconds: 50_000_000)
        await manager.deleteToolCalls(for: conversationID)

        let result = await resultTask.value
        #expect(result?.isError == true)
        #expect(manager.job(for: call.id)?.status == .cancelled)

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await store.fetchRecord(forJobID: call.id) == nil)
    }
}
