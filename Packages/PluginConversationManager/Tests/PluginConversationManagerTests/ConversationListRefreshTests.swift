import Foundation
import KernelCore
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite("Conversation list refresh")
struct ConversationListRefreshTests {
    @Test("消息活跃更新会合并侧栏刷新通知")
    func activeUpdatesAreDebounced() async throws {
        let center = NotificationCenter()
        let eventBus = KernelCoreEventBus(notificationCenter: center)
        let manager = ConversationManager(
            store: nil,
            dataDirectory: FileManager.default.temporaryDirectory,
            eventBus: eventBus
        )
        let conversationID = UUID()
        manager.conversations = [ConversationSummary(id: conversationID)]

        var notificationCount = 0
        let observer = center.addObserver(
            forName: .lumiConversationsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { center.removeObserver(observer) }

        manager.markConversationActive(id: conversationID, messageDate: Date())
        manager.markConversationActive(id: conversationID, messageDate: Date().addingTimeInterval(1))

        #expect(notificationCount == 0)
        try await Task.sleep(for: .milliseconds(260))
        #expect(notificationCount == 1)
    }
}
