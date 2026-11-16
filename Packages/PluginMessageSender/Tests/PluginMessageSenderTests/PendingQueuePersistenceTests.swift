import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginMessageSender

/// 待发队列的落盘与重启恢复（#596）。
///
/// ## 背景
///
/// 会话忙碌时提交的消息只进入内存 `pendingQueues`，输入框却已清空。此前退出
/// 前队列从不落盘：重启后这些「已提交但尚未发出」的正文与附件彻底丢失，用户
/// 以为发出去了，实际无声消失。
///
/// 本套件锁住修复的三个环节：
/// 1. 队列每次变化（入队 / 取消 / 排空）即把完整快照写盘；
/// 2. 启动时把上次未排空的快照装回 sender，回到可见的 Pending 列表；
/// 3. 恢复**不自动拉起回合**，且跳过运行时已删除的会话。
@Suite("MessageSender 待发队列持久化（#596）")
@MainActor
struct PendingQueuePersistenceTests {

    // MARK: - 存储保真

    @Test("队列快照往返保留正文、附件、折叠块与预编码 metadata")
    func storeRoundTripPreservesContentAndAttachments() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = PendingQueueStore(fileURL: fileURL)

        let message = PendingChatMessage(
            conversationID: UUID(),
            content: "queued body",
            imageAttachments: [.fixture()],
            fileAttachments: [.fixture()],
            collapsedBlocks: [CollapsedContentBlock(start: 0, length: 5, title: "粘贴的文本")],
            attachmentMetadata: ["image:0": "payload"]
        )
        try store.save([message])

        #expect(store.load() == [message])
    }

    @Test("空队列落盘删除已有文件，避免过期内容下次被误恢复")
    func emptySaveRemovesExistingFile() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = PendingQueueStore(fileURL: fileURL)

        try store.save([PendingChatMessage(conversationID: UUID(), content: "x")])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try store.save([])
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(store.load().isEmpty)
    }

    @Test("损坏的落盘文件解码为空数组，不阻断启动")
    func corruptFileLoadsEmpty() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("not json".utf8).write(to: fileURL)

        #expect(PendingQueueStore(fileURL: fileURL).load().isEmpty)
    }

    @Test("文件不存在时读取为空数组")
    func missingFileLoadsEmpty() {
        let store = PendingQueueStore(fileURL: Self.temporaryQueueFile())
        #expect(store.load().isEmpty)
    }

    // MARK: - 事件驱动落盘 + 重启恢复（核心）

    @Test("忙碌时提交的消息即时落盘，重启后恢复到新 sender 且不自动发回合")
    func busySubmitPersistsAndSurvivesRestart() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = PendingQueueStore(fileURL: fileURL)

        // 第一次运行：会话忙 → 提交入队，观察器把快照写盘。
        let first = SenderFixture()
        let persistence = PendingQueuePersistence(store: store, sender: first.sender)
        persistence.startObserving()
        defer { persistence.stop() }

        let conversationID = try first.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        first.agentLoop.currentState = .running
        let image = UserImageAttachment.fixture()
        let file = UserFileAttachment.fixture()
        _ = try first.sender.commitUserMessage(
            "queued",
            imageAttachments: [image],
            fileAttachments: [file],
            conversationID: conversationID
        )
        #expect(first.sender.pendingMessages(for: conversationID).count == 1)
        // 入队事件已触发落盘。
        #expect(store.load().map(\.content) == ["queued"])

        // 重启：全新 sender（会话列表尚未加载，不知道这个 conversationID）。
        let second = SenderFixture()
        let restored = PendingQueuePersistence(store: store, sender: second.sender)
        restored.restore()

        let queue = second.sender.pendingMessages(for: conversationID)
        #expect(queue.map(\.content) == ["queued"])
        #expect(queue.first?.imageAttachments == [image])
        #expect(queue.first?.fileAttachments == [file])
        // 恢复只回到 Pending 列表，不自动拉起回合、不落库。
        #expect(second.messages.messages(for: conversationID).isEmpty)
        #expect(second.agentLoop.runTurnCount == 0)
        #expect(second.sender.isSending == false)
    }

    @Test("取消排队消息后落盘同步移除该条")
    func observationPersistsCancelRemoval() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = PendingQueueStore(fileURL: fileURL)

        let fixture = SenderFixture()
        let persistence = PendingQueuePersistence(store: store, sender: fixture.sender)
        persistence.startObserving()
        defer { persistence.stop() }

        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.agentLoop.currentState = .running
        _ = try fixture.sender.commitUserMessage("a", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("b", conversationID: conversationID)
        #expect(store.load().map(\.content) == ["a", "b"])

        let firstID = try #require(fixture.sender.pendingMessages(for: conversationID).first?.id)
        fixture.sender.cancelPendingMessage(id: firstID, in: conversationID)

        #expect(store.load().map(\.content) == ["b"])
    }

    @Test("回合终态排空队列后落盘文件被清除")
    func terminalDrainRemovesPersistedFile() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = PendingQueueStore(fileURL: fileURL)

        let fixture = SenderFixture()
        let persistence = PendingQueuePersistence(store: store, sender: fixture.sender)
        persistence.startObserving()
        defer { persistence.stop() }

        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.agentLoop.currentState = .running
        _ = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        fixture.agentLoop.currentState = .completed
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))

        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - 恢复边界

    @Test("恢复跳过运行时已删除的会话，只装回仍存在的会话")
    func restoreSkipsDeletedConversation() throws {
        let fixture = SenderFixture()
        let deletedID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let liveID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        // 删除会触发 sender 的失效路径，把 deletedID 记入运行时删除集合。
        fixture.conversations.deleteConversation(id: deletedID)

        fixture.sender.restorePendingQueues([
            PendingChatMessage(conversationID: deletedID, content: "gone"),
            PendingChatMessage(conversationID: liveID, content: "kept"),
        ])

        #expect(fixture.sender.pendingMessages(for: deletedID).isEmpty)
        #expect(fixture.sender.pendingMessages(for: liveID).map(\.content) == ["kept"])
    }

    @Test("多会话快照按会话 ID 稳定排序，编码顺序可复现")
    func allPendingMessagesSnapshotIsStablyOrdered() throws {
        let fixture = SenderFixture()
        let idA = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let idB = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.agentLoop.currentState = .running
        _ = try fixture.sender.commitUserMessage("a1", conversationID: idA)
        _ = try fixture.sender.commitUserMessage("a2", conversationID: idA)
        _ = try fixture.sender.commitUserMessage("b1", conversationID: idB)

        let snapshot = fixture.sender.allPendingMessages
        // 会话间按 uuidString 升序排列（与具体 ID 大小无关）。
        #expect(snapshot.map(\.conversationID) == snapshot.map(\.conversationID).sorted { $0.uuidString < $1.uuidString })
        // 同一会话内保持先进先出。
        #expect(snapshot.filter { $0.conversationID == idA }.map(\.content) == ["a1", "a2"])
        #expect(snapshot.filter { $0.conversationID == idB }.map(\.content) == ["b1"])
        // 再次读取顺序一致。
        #expect(fixture.sender.allPendingMessages == snapshot)
    }

    // MARK: - 插件装配

    @Test("插件启动时从落盘文件恢复待发队列")
    func pluginBootRestoresPersistedQueue() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let conversationID = UUID()
        try PendingQueueStore(fileURL: fileURL).save([
            PendingChatMessage(conversationID: conversationID, content: "survived"),
        ])

        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        let plugin = MessageSenderPlugin()
        plugin.pendingQueueStore = PendingQueueStore(fileURL: fileURL)
        try kernel.start(plugins: [plugin])

        let sender = try #require(kernel.resolveProvider((any MessageSendingProviding).self) as? MessageSender)
        #expect(sender.pendingMessages(for: conversationID).map(\.content) == ["survived"])
        #expect(messages.messages(for: conversationID).isEmpty)
    }

    @Test("插件退出前兜底落盘当前队列")
    func pluginShutdownFlushesQueueToDisk() throws {
        let fileURL = Self.temporaryQueueFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        let plugin = MessageSenderPlugin()
        plugin.pendingQueueStore = PendingQueueStore(fileURL: fileURL)
        try kernel.start(plugins: [plugin])

        let sender = try #require(kernel.resolveProvider((any MessageSendingProviding).self) as? MessageSender)
        let conversationID = try conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        agentLoop.currentState = .running
        _ = try sender.commitUserMessage("pending", conversationID: conversationID)

        try plugin.onShutdown(kernel: kernel)

        #expect(PendingQueueStore(fileURL: fileURL).load().map(\.content) == ["pending"])
        #expect(agentLoop.observerCount == 0)
    }

    // MARK: - Helpers

    private static func temporaryQueueFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-queue-\(UUID().uuidString).json")
    }
}