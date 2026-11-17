import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 回归 #439：启动加载是「await 读快照 → 写回内存」两段式。await 期间用户
/// 新建并选中的会话，不能被随后晚到的旧快照覆盖，选中态也不得被劫持回快照首项。
/// 用门闩把旧快照挡在写回之前，确定性地构造「旧请求晚到」（仓库异步写回约定）。
@MainActor
@Suite(.serialized)
struct ConversationStartupSnapshotMergeTests {
    @Test func startupSnapshotMergesConversationCreatedDuringLoad() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationStartupMerge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let oldID = UUID()
        try await store.createConversation(id: oldID, title: "Old", createdAt: Date())

        // 持久化选中指向旧会话：启动恢复本应回到它，但用户在加载期间新建了会话。
        let stateJSON = Data("{\"selectedConversationID\":\"\(oldID.uuidString)\"}".utf8)
        try stateJSON.write(to: directory.appendingPathComponent("state.json"))

        let manager = ConversationManager(store: store, dataDirectory: directory)

        // 旧快照在加载开始时就已确定（只含旧会话），门闩让它晚于新建会话写回。
        let staleSnapshot = await store.fetchConversationPage(limit: 40)
        let gate = SnapshotGate()
        manager.loadSnapshotProvider = { _ in
            gate.signalReached()
            await gate.waitUntilReleased()
            return staleSnapshot
        }

        manager.loadConversations()
        await gate.waitUntilReached()

        // 加载尚停在旧快照的 await 上：用户新建并选中一个会话。
        let newID = try manager.createConversation(
            title: "New during load",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(manager.selectedConversationID == newID)
        #expect(manager.conversations.contains { $0.id == newID })

        // 放行旧快照写回。
        gate.release()
        for _ in 0..<200 where manager.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!manager.isLoadingConversations)

        // 新建会话必须存活，旧会话被合并进来，选中态停在新会话而非被劫持回旧会话。
        #expect(manager.conversations.contains { $0.id == newID })
        #expect(manager.conversations.contains { $0.id == oldID })
        #expect(manager.selectedConversationID == newID)
        #expect(manager.currentTitle == "New during load")

        // 等新建会话落库后再清理临时目录，避免后台 Task 仍在 fault 时删库。
        for _ in 0..<200 where await store.fetchConversation(id: newID) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// 加载期间没有任何本地改动时，启动恢复仍须回到持久化选中（不因合并修复而回归）。
    @Test func loadWithoutLocalChangesRestoresPersistedSelection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationStartupRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let oldID = UUID()
        try await store.createConversation(id: oldID, title: "Old", createdAt: Date())
        let stateJSON = Data("{\"selectedConversationID\":\"\(oldID.uuidString)\"}".utf8)
        try stateJSON.write(to: directory.appendingPathComponent("state.json"))

        let manager = ConversationManager(store: store, dataDirectory: directory)
        manager.loadConversations()
        for _ in 0..<200 where manager.isLoadingConversations {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!manager.isLoadingConversations)
        #expect(manager.conversations.contains { $0.id == oldID })
        #expect(manager.selectedConversationID == oldID)
    }
}

/// 门闩：把启动快照的写回挡在放行之前，并让测试确定性地等到加载已停在 await 上。
@MainActor
private final class SnapshotGate {
    private var reachedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var reached = false
    private var released = false

    func signalReached() {
        reached = true
        reachedContinuation?.resume()
        reachedContinuation = nil
    }

    func waitUntilReached() async {
        if reached { return }
        await withCheckedContinuation { reachedContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitUntilReleased() async {
        if released { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }
}