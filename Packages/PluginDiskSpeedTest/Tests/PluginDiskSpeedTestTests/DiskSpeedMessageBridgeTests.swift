import Foundation
import ProviderMessage
import Testing
@testable import PluginDiskSpeedTest

/// 记录消息变更的消息管理器替身。
///
/// 只实现本插件实际用到的两个动作（插入 / 更新），
/// 足以验证「先插进行中卡片、测完再回填完成结果」这条链路。
@MainActor
private final class RecordingMessageManager: MessageManaging {
    private(set) var inserted: [Message] = []
    private(set) var updated: [(id: UUID, content: String)] = []

    func insertMessage(_ message: Message, to conversationID: UUID) {
        inserted.append(message)
    }

    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        updated.append((id, content))
    }

    // 以下方法本插件不使用，返回空实现即可满足协议。
    func messages(for conversationID: UUID) -> [Message] { inserted }
    func message(id: UUID, in conversationID: UUID) -> Message? {
        inserted.first { $0.id == id }
    }
    func lastMessage(in conversationID: UUID) -> Message? { inserted.last }
    func messageCount(for conversationID: UUID) -> Int { inserted.count }
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) {}
    func messagesForLLM(in conversationID: UUID) async -> [Message] { inserted }
    func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }
    func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }

    /// 本插件不使用工具调用结果更新，实现协议要求的方法即可。
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
}

@Suite("DiskSpeedMessageBridge")
@MainActor
struct DiskSpeedMessageBridgeTests {

    @Test("insert adds a card and returns its id")
    func insertAddsCardAndReturnsID() {
        let manager = RecordingMessageManager()
        let bridge = DiskSpeedMessageBridge()
        bridge.configure(messages: manager)

        let conversationID = UUID()
        let messageID = bridge.insert(
            conversationID: conversationID,
            turnID: nil,
            payload: .running(directory: "/tmp")
        )

        #expect(messageID != nil)
        #expect(manager.inserted.count == 1)
        #expect(manager.inserted.first?.id == messageID)
        #expect(manager.inserted.first?.conversationID == conversationID)
    }

    /// 关键回归：状态推进必须改的是同一条消息的 content。
    ///
    /// 载荷存在 content 里（因为 metadata 不可更新），
    /// 因此回填时必须写 content，否则卡片会永远停在「进行中」。
    @Test("update rewrites the content of the same message")
    func updateRewritesSameMessageContent() {
        let manager = RecordingMessageManager()
        let bridge = DiskSpeedMessageBridge()
        bridge.configure(messages: manager)

        let conversationID = UUID()
        let messageID = bridge.insert(
            conversationID: conversationID,
            turnID: nil,
            payload: .running(directory: "/tmp")
        )

        let finished = DiskSpeedPayload.finished(
            readBytesPerSecond: 1_200_000_000,
            writeBytesPerSecond: 900_000_000,
            readBytes: 256 * 1024 * 1024,
            writeBytes: 256 * 1024 * 1024
        )
        bridge.update(
            messageID: messageID!,
            conversationID: conversationID,
            payload: finished
        )

        #expect(manager.updated.count == 1)
        #expect(manager.updated.first?.id == messageID)

        // 更新后的 content 必须能还原出完成状态。
        let decoded = DiskSpeedTimeline.decodePayload(from: manager.updated.first!.content)
        #expect(decoded?.phase == .finished)
        #expect(decoded?.readBytesPerSecond == 1_200_000_000)
        #expect(decoded?.writeBytesPerSecond == 900_000_000)
    }

    @Test("bridge without a message manager is a no-op instead of crashing")
    func bridgeWithoutManagerIsNoOp() {
        let bridge = DiskSpeedMessageBridge()
        let messageID = bridge.insert(
            conversationID: UUID(),
            turnID: nil,
            payload: .running(directory: "/tmp")
        )
        #expect(messageID == nil)
    }
}
