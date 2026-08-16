import Foundation
import Testing
@testable import ProviderMessage

@Suite("ProviderMessage")
@MainActor
struct ProviderMessageTests {
    @Test("消息按创建时间返回并支持更新删除")
    func lifecycle() {
        let manager = DefaultMessageManaging()
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
}
