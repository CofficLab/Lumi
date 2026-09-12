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

        let notificationCount = LockedNotificationCount()
        let observer = center.addObserver(
            forName: .lumiConversationsDidChange,
            object: nil,
            queue: nil
        ) { _ in
            notificationCount.increment()
        }
        defer { center.removeObserver(observer) }

        manager.markConversationActive(id: conversationID, messageDate: Date())
        manager.markConversationActive(id: conversationID, messageDate: Date().addingTimeInterval(1))

        #expect(notificationCount.value == 0)
        for _ in 0..<100 where notificationCount.value == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notificationCount.value == 1)
    }
}

private final class LockedNotificationCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}
