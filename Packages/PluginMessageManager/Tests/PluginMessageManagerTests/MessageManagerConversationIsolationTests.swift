import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 上下文弹窗（ContextToolbarView）的消息数据源必须严格按对话隔离。
///
/// ## 为什么需要这组测试
///
/// 弹窗的趋势曲线 / 压缩记录来自 `messagesSnapshot(in:)`，用量估算来自
/// `messagesForLLM(in:)`。用户质疑：界面展示的是否一定是「当前对话」的 token
/// 数据，会不会混入其他对话？
///
/// 这组测试把「任一对话的读路径只含该对话自己的消息」固化成不变量：
/// 两个对话各自写入带**不同 token 数**的消息，并发交错写入后，任一对话的
/// 快照 / LLM 读取 / 同步读取都不得出现另一个对话的消息 ID 或 token。
/// 若这些断言变红，说明读路径或写入归属确实存在跨对话泄漏。
///
/// ## 覆盖的层
///
/// - `MessageStore.fetchMessages` / `fetchMessagesForLLMContext`（磁盘按 conversationId 过滤）
/// - `PendingMessageBuffer`（write-behind 脏数据按 conversationID 分桶）
/// - `MessageManager` 的磁盘 + pending 合并（read-your-writes 窗口）
/// - `insertMessage` 对 conversationID 不一致消息的重建
@MainActor
@Suite("上下文弹窗消息数据源的对话隔离")
struct MessageManagerConversationIsolationTests {

    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageIsolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    /// 构造一条带可区分 token 数的 assistant 消息。
    private func assistant(
        _ conversationID: UUID,
        index: Int,
        tokens: Int,
        createdAt: Date = Date()
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "conv=\(conversationID.uuidString.prefix(8)) idx=\(index)",
            createdAt: createdAt,
            inputTokenCount: tokens,
            cachedInputTokenCount: tokens - 1
        )
    }

    /// 轮询直到某条消息落盘（write-behind 后台串行队列最终一致）。
    private func waitUntilPersisted(
        _ store: MessageStore,
        conversationID: UUID,
        messageID: UUID
    ) async throws {
        for _ in 0..<200 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == messageID }) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("消息 \(messageID.uuidString.prefix(8)) 未在预期时间内落盘")
    }

    /// 轮询直到某条消息的磁盘内容更新到指定值。
    private func waitUntilContent(
        _ store: MessageStore,
        conversationID: UUID,
        messageID: UUID,
        content: String
    ) async throws {
        for _ in 0..<200 {
            if store.fetchMessages(conversationId: conversationID)
                .first(where: { $0.id == messageID })?.content == content {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("消息 \(messageID.uuidString.prefix(8)) 内容未更新到预期值")
    }

    // MARK: - 磁盘读路径

    @Test("messagesSnapshot 只含目标对话的消息")
    func snapshotIsConversationScoped() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        let aMessages = (0..<5).map { assistant(a, index: $0, tokens: 1_000 + $0) }
        let bMessages = (0..<5).map { assistant(b, index: $0, tokens: 90_000 + $0) }
        for message in aMessages + bMessages {
            try store.insertMessage(message)
        }

        let snapshot = await manager.messagesSnapshot(in: a)
        let aIDs = Set(aMessages.map(\.id))
        let bIDs = Set(bMessages.map(\.id))

        #expect(snapshot.count == aMessages.count)
        #expect(Set(snapshot.map(\.id)) == aIDs, "快照只能含对话 A 的消息")
        #expect(snapshot.allSatisfy { $0.conversationID == a }, "每条消息的 conversationID 必须是 A")
        #expect(snapshot.allSatisfy { !bIDs.contains($0.id) }, "不得混入对话 B 的消息")
        #expect(snapshot.allSatisfy { ($0.inputTokenCount ?? 0) < 90_000 }, "不得混入 B 的高 token 采样")
    }

    @Test("messagesForLLM 只含目标对话的消息")
    func llmReadIsConversationScoped() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        let aMessages = (0..<4).map { assistant(a, index: $0, tokens: 2_000 + $0) }
        let bMessages = (0..<4).map { assistant(b, index: $0, tokens: 80_000 + $0) }
        for message in aMessages + bMessages {
            try store.insertMessage(message)
        }

        let llm = await manager.messagesForLLM(in: a)
        #expect(Set(llm.map(\.id)) == Set(aMessages.map(\.id)))
        #expect(llm.allSatisfy { $0.conversationID == a })
        #expect(llm.allSatisfy { ($0.inputTokenCount ?? 0) < 80_000 })
    }

    @Test("同步 messages(for:) 只含目标对话的消息")
    func syncReadIsConversationScoped() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        let aMessages = (0..<3).map { assistant(a, index: $0, tokens: 3_000 + $0) }
        let bMessages = (0..<3).map { assistant(b, index: $0, tokens: 70_000 + $0) }
        for message in aMessages + bMessages {
            try store.insertMessage(message)
        }

        let read = manager.messages(for: a)
        #expect(Set(read.map(\.id)) == Set(aMessages.map(\.id)))
        #expect(read.allSatisfy { $0.conversationID == a })
    }

    // MARK: - write-behind 窗口（pending 缓冲）

    @Test("落盘前的 read-your-writes 窗口仍按对话隔离")
    func pendingWindowIsConversationScoped() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        // 交错写入 A / B，此刻消息可能仍在 pending 缓冲、尚未落盘。
        var aIDs: Set<UUID> = []
        var bIDs: Set<UUID> = []
        for index in 0..<6 {
            let am = assistant(a, index: index, tokens: 4_000 + index)
            let bm = assistant(b, index: index, tokens: 60_000 + index)
            aIDs.insert(am.id); bIDs.insert(bm.id)
            manager.insertMessage(am, to: a)
            manager.insertMessage(bm, to: b)
        }

        // pending 缓冲本身按对话分桶。
        #expect(Set(manager.pending.snapshot(for: a).map(\.id)).isSubset(of: aIDs))
        #expect(Set(manager.pending.snapshot(for: b).map(\.id)).isSubset(of: bIDs))
        #expect(manager.pending.snapshot(for: a).allSatisfy { $0.conversationID == a })

        // 读路径合并磁盘 + pending 后仍只含本对话。
        let snapshotA = await manager.messagesSnapshot(in: a)
        #expect(Set(snapshotA.map(\.id)) == aIDs)
        #expect(snapshotA.allSatisfy { !bIDs.contains($0.id) })
        #expect(snapshotA.allSatisfy { ($0.inputTokenCount ?? 0) < 60_000 })

        let snapshotB = await manager.messagesSnapshot(in: b)
        #expect(Set(snapshotB.map(\.id)) == bIDs)
        #expect(snapshotB.allSatisfy { !aIDs.contains($0.id) })
    }

    @Test("并发交错写入两个对话不互相泄漏")
    func concurrentInsertsDoNotLeak() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        // 大量交错写入，压测 pending 分桶与后台串行落盘的归属。
        var aIDs: Set<UUID> = []
        var bIDs: Set<UUID> = []
        for index in 0..<60 {
            let am = assistant(a, index: index, tokens: 5_000 + index)
            let bm = assistant(b, index: index, tokens: 50_000 + index)
            aIDs.insert(am.id); bIDs.insert(bm.id)
            manager.insertMessage(am, to: a)
            manager.insertMessage(bm, to: b)
        }

        // 并发读取两个对话，读路径不得串桶。
        async let readA = manager.messagesSnapshot(in: a)
        async let readB = manager.messagesSnapshot(in: b)
        let (snapshotA, snapshotB) = await (readA, readB)
        #expect(Set(snapshotA.map(\.id)) == aIDs)
        #expect(Set(snapshotB.map(\.id)) == bIDs)
        #expect(snapshotA.allSatisfy { $0.conversationID == a })
        #expect(snapshotB.allSatisfy { $0.conversationID == b })

        // 等待后台落盘完成后，磁盘侧同样按对话隔离。
        var persisted = false
        for _ in 0..<200 {
            if store.fetchMessages(conversationId: a).count == aIDs.count,
               store.fetchMessages(conversationId: b).count == bIDs.count {
                persisted = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(persisted, "两个对话的消息都应最终落盘")
        #expect(Set(store.fetchMessages(conversationId: a).map(\.id)) == aIDs)
        #expect(Set(store.fetchMessages(conversationId: b).map(\.id)) == bIDs)
    }

    // MARK: - 写入归属

    @Test("conversationID 不一致的消息被重建到目标对话")
    func mismatchedConversationIDIsRebuiltToTarget() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        // 消息自身标记为 B，但插入目标是 A：必须落到 A，且不得污染 B。
        let stray = assistant(b, index: 0, tokens: 12_345)
        manager.insertMessage(stray, to: a)

        let snapshotA = await manager.messagesSnapshot(in: a)
        let snapshotB = await manager.messagesSnapshot(in: b)
        #expect(snapshotA.contains { $0.id == stray.id })
        #expect(snapshotA.allSatisfy { $0.conversationID == a }, "重建后 conversationID 必须是目标 A")
        #expect(!snapshotB.contains { $0.id == stray.id }, "不得写入消息原标记的 B")
    }

    @Test("更新只作用于目标对话")
    func updateIsConversationScoped() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        let am = assistant(a, index: 0, tokens: 1_000)
        let bm = assistant(b, index: 0, tokens: 2_000)
        manager.insertMessage(am, to: a)
        manager.insertMessage(bm, to: b)

        // 先等两条插入落盘，避免插入与更新在后台串行队列里交错产生时序窗口。
        // 本测试验证的是「更新按对话隔离」，不是 write-behind 的即时一致性。
        try await waitUntilPersisted(store, conversationID: a, messageID: am.id)
        try await waitUntilPersisted(store, conversationID: b, messageID: bm.id)

        manager.updateMessage(id: am.id, in: a, content: "A 已更新")
        try await waitUntilContent(store, conversationID: a, messageID: am.id, content: "A 已更新")

        let snapshotA = await manager.messagesSnapshot(in: a)
        let snapshotB = await manager.messagesSnapshot(in: b)
        #expect(snapshotA.first { $0.id == am.id }?.content == "A 已更新")
        #expect(snapshotB.first { $0.id == bm.id }?.content == bm.content, "B 的消息不得被改动")
    }

    @Test("删除只作用于目标对话")
    func deleteIsConversationScoped() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let a = UUID(), b = UUID()

        let am = assistant(a, index: 0, tokens: 1_000)
        let bm = assistant(b, index: 0, tokens: 2_000)
        manager.insertMessage(am, to: a)
        manager.insertMessage(bm, to: b)

        manager.deleteMessage(id: am.id, in: a)

        let snapshotA = await manager.messagesSnapshot(in: a)
        let snapshotB = await manager.messagesSnapshot(in: b)
        #expect(!snapshotA.contains { $0.id == am.id })
        #expect(snapshotB.contains { $0.id == bm.id }, "B 的消息不得被误删")
    }

    // MARK: - 现象刻画：同一对话内的并行流

    @Test("写入同一对话的两条流都会如实出现在该对话快照里")
    func snapshotReflectsAllStreamsWrittenToSameConversation() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MessageManager(store: store, dataDirectory: directory)
        let conversation = UUID()

        // 模拟两条并行请求流（低上下文链 / 高上下文链）写入同一个对话。
        // 这不是跨对话泄漏：两条流都属于本对话，读路径如实呈现。
        let lowChain = (0..<4).map { assistant(conversation, index: $0, tokens: 20_000 + $0 * 1_000) }
        let highChain = (0..<4).map { assistant(conversation, index: 100 + $0, tokens: 90_000 + $0 * 1_000) }
        for index in 0..<4 {
            manager.insertMessage(lowChain[index], to: conversation)
            manager.insertMessage(highChain[index], to: conversation)
        }

        let snapshot = await manager.messagesSnapshot(in: conversation)
        let allIDs = Set((lowChain + highChain).map(\.id))
        #expect(Set(snapshot.map(\.id)) == allIDs, "同一对话的两条流都应可见")
        #expect(snapshot.allSatisfy { $0.conversationID == conversation })
        // 趋势曲线按时间排序时会交替看到低 / 高链采样 —— 这正是「突然降下来」的来源，
        // 而非混入了其他对话的数据。
        let tokens = snapshot.compactMap(\.inputTokenCount)
        #expect(tokens.contains { $0 < 30_000 })
        #expect(tokens.contains { $0 > 90_000 })
    }
}