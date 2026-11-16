import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

/// 快速产生大量输出块的工具：每个 chunk 都 enqueue 一次持久化写入，
/// 用于在终态写入前堆积一条足够长的持久化链，暴露「退出未等待链」的窗口。
private struct BurstOutputTool: SuperAgentTool, @unchecked Sendable {
    let name = "burst_output"
    let chunks: Int

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String { "done" }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        for index in 0..<chunks {
            await context.reportOutput(.stdout, "chunk-\(index)\n")
        }
        return ToolCallResult(content: "done")
    }
}

/// 回归 #1164：退出前必须停止接收新 Job 并等待有序持久化链落盘，
/// 否则快速重启会把已成功的终态 Job 恢复成 failed，丢掉结果。
struct ToolJobShutdownDrainTests {
    private func makeStore() throws -> (ToolJobRecordStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobShutdownDrainTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (ToolJobRecordStore(databaseRootURL: directory), directory)
    }

    @MainActor
    @Test("退出 drain 等待持久化链：终态 Job 重启后仍为 completed（#1164）")
    func shutdownDrainPersistsTerminalStateBeforeRestart() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ToolManager()
        manager.jobRecordStore = store
        manager.add(BurstOutputTool(chunks: 400), pluginID: "test")
        let call = ToolCall(id: "drain-1", name: "burst_output", arguments: "{}")
        let conversationID = UUID()
        let jobs = manager.submit(
            [call],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: UUID()
        )
        let jobID = try #require(jobs.first?.id)
        let result = await manager.waitForJobResult(jobID: jobID)
        #expect(result?.content == "done")

        // 终态快照已排在链尾，但 400 个输出写入可能尚未落盘。
        // drain 必须同步等待整条链，而不是立即返回。
        manager.toolExecutionManager.drainPersistenceOnShutdown()

        // drain 返回后终态必须已 durable（不再轮询等待）。
        let durable = await store.fetchRecord(forJobID: jobID)
        #expect(durable?.status == .completed)
        #expect(durable?.result?.content == "done")

        // 重启：复用终态快照，不得把 running 恢复成 failed。
        let restarted = ToolManager()
        restarted.jobRecordStore = store
        var restored: ToolJob?
        for _ in 0..<40 {
            restored = restarted.job(for: jobID)
            if restored != nil { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(restored?.status == .completed)
        #expect(restored?.errorMessage == nil)
    }

    @MainActor
    @Test("退出 drain 后不再接收新 Job（#1164）")
    func shutdownRejectsNewJobSubmission() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ToolManager()
        manager.jobRecordStore = store
        manager.add(BurstOutputTool(chunks: 1), pluginID: "test")
        manager.toolExecutionManager.drainPersistenceOnShutdown()

        let jobs = manager.submit(
            [ToolCall(id: "late", name: "burst_output", arguments: "{}")],
            policy: .autoExecute,
            conversationID: UUID(),
            turnID: UUID()
        )
        #expect(jobs.isEmpty)
    }

    @MainActor
    @Test("没有待写入时 drain 安全返回，不悬挂（#1164）")
    func drainWithNoPendingWritesIsSafe() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ToolManager()
        manager.jobRecordStore = store
        manager.toolExecutionManager.drainPersistenceOnShutdown()

        #expect(await store.fetchAllJobs().isEmpty)
    }
}