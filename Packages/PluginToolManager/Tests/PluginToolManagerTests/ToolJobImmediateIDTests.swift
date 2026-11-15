import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

@Suite("立即失败 Job 的内部 ID 独立性", .serialized)
struct ToolJobImmediateIDTests {

    @MainActor
    private func makeManager() -> ToolManager {
        ToolManager()
    }

    private func makeStore() throws -> (ToolJobRecordStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobImmediateIDTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (ToolJobRecordStore(databaseRootURL: directory), directory)
    }

    // MARK: - 未知工具

    @MainActor
    @Test("不同回合复用同一协议 ID 的未知工具调用产生独立 Job")
    func unknownToolSameProtocolIDDifferentTurns() async throws {
        let manager = makeManager()
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()
        let call = ToolCall(id: "call_0", name: "missing", arguments: "{}")

        let jobsA = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnA)
        let jobsB = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnB)

        let jobA = try #require(jobsA.first)
        let jobB = try #require(jobsB.first)

        #expect(jobA.id != jobB.id)
        #expect(jobA.id != "call_0")
        #expect(jobB.id != "call_0")
        #expect(jobA.toolCall.id == "call_0")
        #expect(jobB.toolCall.id == "call_0")
        #expect(jobA.status == .failed)
        #expect(jobB.status == .failed)

        let fetchedA = manager.job(for: jobA.id)
        let fetchedB = manager.job(for: jobB.id)
        #expect(fetchedA?.id == jobA.id)
        #expect(fetchedB?.id == jobB.id)
        #expect(fetchedA?.turnID == turnA)
        #expect(fetchedB?.turnID == turnB)
    }

    @MainActor
    @Test("不同会话复用同一协议 ID 的未知工具调用产生独立 Job")
    func unknownToolSameProtocolIDDifferentConversations() async throws {
        let manager = makeManager()
        let convA = UUID()
        let convB = UUID()
        let call = ToolCall(id: "call_0", name: "missing", arguments: "{}")

        let jobsA = manager.submit([call], policy: .autoExecute, conversationID: convA, turnID: UUID())
        let jobsB = manager.submit([call], policy: .autoExecute, conversationID: convB, turnID: UUID())

        let jobA = try #require(jobsA.first)
        let jobB = try #require(jobsB.first)

        #expect(jobA.id != jobB.id)
        #expect(manager.job(for: jobA.id)?.conversationID == convA)
        #expect(manager.job(for: jobB.id)?.conversationID == convB)
    }

    // MARK: - 参数解码失败

    @MainActor
    @Test("不同回合复用同一协议 ID 的畸形参数调用产生独立 Job")
    func malformedArgumentsSameProtocolIDDifferentTurns() async throws {
        let manager = makeManager()
        manager.add(EchoTool(), pluginID: "test")
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()
        let call = ToolCall(id: "call_0", name: "echo", arguments: "not-json")

        let jobsA = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnA)
        let jobsB = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnB)

        let jobA = try #require(jobsA.first)
        let jobB = try #require(jobsB.first)

        #expect(jobA.id != jobB.id)
        #expect(jobA.id != "call_0")
        #expect(jobB.id != "call_0")
        #expect(jobA.status == .failed)
        #expect(jobB.status == .failed)
        #expect(manager.job(for: jobA.id)?.turnID == turnA)
        #expect(manager.job(for: jobB.id)?.turnID == turnB)
    }

    // MARK: - 持久化不互相覆盖

    @MainActor
    @Test("立即失败的 Job 持久化后按独立 ID 各自可恢复")
    func immediateFailuresPersistIndependently() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = makeManager()
        manager.jobRecordStore = store
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()
        let call = ToolCall(id: "call_0", name: "missing", arguments: "{}")

        let jobsA = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnA)
        let jobsB = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnB)
        let jobA = try #require(jobsA.first)
        let jobB = try #require(jobsB.first)

        var recordA: ToolJobRecord?
        var recordB: ToolJobRecord?
        for _ in 0..<40 {
            recordA = await store.fetchRecord(forJobID: jobA.id)
            recordB = await store.fetchRecord(forJobID: jobB.id)
            if recordA != nil && recordB != nil { break }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(recordA != nil)
        #expect(recordB != nil)
        #expect(recordA?.id == jobA.id)
        #expect(recordB?.id == jobB.id)
        #expect(recordA?.turnID == turnA)
        #expect(recordB?.turnID == turnB)
    }

    // MARK: - 同回合去重仍生效

    @MainActor
    @Test("同回合内相同协议 ID 仍去重返回已有 Job")
    func sameTurnDedupStillWorks() async throws {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let call = ToolCall(id: "call_0", name: "missing", arguments: "{}")

        let first = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnID)
        let second = manager.submit([call], policy: .autoExecute, conversationID: conversationID, turnID: turnID)

        let jobA = try #require(first.first)
        let jobB = try #require(second.first)
        #expect(jobA.id == jobB.id)
    }
}

private struct EchoTool: SuperAgentTool {
    let name = "echo"
    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "ok" }
}