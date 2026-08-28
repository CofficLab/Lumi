import Foundation
import Testing
@testable import ProviderMessage

@Suite("ProviderMessage")
@MainActor
struct ProviderMessageTests {
    @Test("消息按创建时间返回并支持更新删除")
    func lifecycle() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        let first = Message(conversationID: conversationID, role: .user, content: "hello")
        let second = Message(conversationID: conversationID, role: .assistant, content: "world")

        manager.insertMessage(first, to: conversationID)
        manager.insertMessage(second, to: conversationID)
        #expect(manager.messages(for: conversationID).map(\.id) == [first.id, second.id])
        manager.updateMessage(id: first.id, in: conversationID, content: "updated")
        #expect(manager.message(id: first.id, in: conversationID)?.content == "updated")
        manager.deleteMessage(id: second.id, in: conversationID)
        #expect(manager.messageCount(for: conversationID) == 1)
    }

    @Test("消息与 token 可按自然日跨会话聚合")
    func dailyAggregates() {
        let manager = DefaultMessageManager()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let firstConversation = UUID()
        let secondConversation = UUID()

        manager.insertMessage(
            Message(conversationID: firstConversation, role: .user, content: "one", createdAt: yesterday, inputTokenCount: 12),
            to: firstConversation
        )
        manager.insertMessage(
            Message(conversationID: secondConversation, role: .assistant, content: "two", createdAt: yesterday, outputTokenCount: 8),
            to: secondConversation
        )
        manager.insertMessage(
            Message(conversationID: firstConversation, role: .assistant, content: "three", createdAt: today, inputTokenCount: 3, outputTokenCount: 5),
            to: firstConversation
        )

        #expect(manager.dailyMessageCounts(since: yesterday) == [yesterday: 2, today: 1])
        #expect(manager.dailyTokenCounts(since: yesterday) == [yesterday: 20, today: 8])
    }

    @Test("消息插入观察者可接收事件并注销")
    func messageInsertionObservation() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        var observed: [(UUID, UUID)] = []
        let handle = manager.addMessageInsertedObserver { message, conversation in
            observed.append((message.id, conversation))
        }
        let first = Message(conversationID: conversationID, role: .user, content: "first")
        manager.insertMessage(first, to: conversationID)
        handle.cancel()
        manager.insertMessage(Message(conversationID: conversationID, role: .assistant, content: "second"), to: conversationID)

        #expect(observed.count == 1)
        #expect(observed.first?.0 == first.id)
        #expect(observed.first?.1 == conversationID)
    }
}
