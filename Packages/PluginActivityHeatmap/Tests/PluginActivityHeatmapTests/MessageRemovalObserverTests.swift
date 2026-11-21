import Foundation
import ProviderMessage
import Testing
@testable import PluginActivityHeatmap

/// 删除/清空触发的热力图刷新观察者测试（#238）。
@Suite("Activity heatmap message removal observer", .serialized)
@MainActor
struct MessageRemovalObserverTests {
    @Test("deletion and clear fire the callback; insertion and update do not (#238)")
    func firesOnlyOnRemovalChanges() async {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        var removalCount = 0
        let observer = MessageRemovalObserver(messages: manager) {
            removalCount += 1
        }

        let message = Message(conversationID: conversationID, role: .user, content: "hello")
        manager.insertMessage(message, to: conversationID)
        #expect(removalCount == 0)

        manager.updateMessage(id: message.id, in: conversationID, content: "edited")
        #expect(removalCount == 0)

        manager.deleteMessage(id: message.id, in: conversationID)
        #expect(removalCount == 1)

        manager.insertMessage(message, to: conversationID)
        manager.clearMessages(in: conversationID)
        #expect(removalCount == 2)

        observer.cancel()
        manager.deleteMessage(id: message.id, in: conversationID)
        #expect(removalCount == 2)
    }
}
