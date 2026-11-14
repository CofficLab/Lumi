import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 持久化 `firstUserMessage` 的「第一条非空白用户消息」契约（见 issue #838）。
///
/// 纯附件消息正文为空，若磁盘查询只按 `role == user` 取最早一条，最早的空白
/// 附件消息会挡住其后真正的文本消息：API 返回空白消息，标题服务因
/// `firstUserMessage.id == message.id` 不匹配而拒绝为文本生成标题，启动补填
/// 同样拿到空白消息跳过，会话永远 Untitled。
///
/// 本套件锁定磁盘查询与重开 manager（无 pending、纯磁盘）两条路径都跳过空白。
@MainActor
@Suite("首条用户消息跳过空白附件")
struct FirstUserMessageBlankFilterTests {

    @Test("持久化查询跳过纯附件空白消息，返回其后第一条文本（#838）")
    func persistedQuerySkipsBlankAttachmentMessage() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let base = Date()

        let blank = Message(
            conversationID: conversationID,
            role: .user,
            content: "",
            createdAt: base,
            imageAttachments: [MessageImageAttachment(data: "aW1hZ2U=")]
        )
        let text = Message(
            conversationID: conversationID,
            role: .user,
            content: "Investigate login timeout",
            createdAt: base.addingTimeInterval(1)
        )
        manager.insertMessage(blank, to: conversationID)
        manager.insertMessage(text, to: conversationID)
        try await waitUntilPersisted(store: store, conversationID: conversationID, ids: [blank.id, text.id])

        let first = store.fetchFirstUserMessage(conversationId: conversationID)
        #expect(first?.id == text.id)
        #expect(first?.content == "Investigate login timeout")
    }

    @Test("重启后从磁盘读取首条用户消息仍跳过空白附件消息（#838）")
    func reopenedManagerReadsFirstNonBlankFromDisk() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let base = Date()

        let blank = Message(
            conversationID: conversationID,
            role: .user,
            content: "",
            createdAt: base,
            imageAttachments: [MessageImageAttachment(data: "aW1hZ2U=")]
        )
        let text = Message(
            conversationID: conversationID,
            role: .user,
            content: "Investigate login timeout",
            createdAt: base.addingTimeInterval(1)
        )
        manager.insertMessage(blank, to: conversationID)
        manager.insertMessage(text, to: conversationID)
        try await waitUntilPersisted(store: store, conversationID: conversationID, ids: [blank.id, text.id])

        // 重开 manager：没有 pending，完全走磁盘路径。
        let reopened = MessageManager(
            store: try MessageStore(databaseRootURL: directory),
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
        let first = await reopened.firstUserMessage(in: conversationID)
        #expect(first?.id == text.id)
    }

    @Test("纯空白正文的用户消息也被跳过（#838）")
    func persistedQuerySkipsWhitespaceOnlyMessage() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let base = Date()

        let whitespace = Message(
            conversationID: conversationID,
            role: .user,
            content: "   \n\t",
            createdAt: base
        )
        let text = Message(
            conversationID: conversationID,
            role: .user,
            content: "real text",
            createdAt: base.addingTimeInterval(1)
        )
        manager.insertMessage(whitespace, to: conversationID)
        manager.insertMessage(text, to: conversationID)
        try await waitUntilPersisted(store: store, conversationID: conversationID, ids: [whitespace.id, text.id])

        #expect(store.fetchFirstUserMessage(conversationId: conversationID)?.id == text.id)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FirstUserMsgBlank-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore?) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    /// 轮询直到指定消息全部落盘（写入经由后台 persistQueue 异步完成）。
    private func waitUntilPersisted(
        store: MessageStore,
        conversationID: UUID,
        ids: [UUID]
    ) async throws {
        let wanted = Set(ids)
        for _ in 0..<200 {
            let persisted = Set(store.fetchMessages(conversationId: conversationID).map(\.id))
            if wanted.isSubset(of: persisted) { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("消息未在预期时间内落盘：\(ids)")
    }
}