import Foundation
import Testing
import EditorService
@testable import EditorChatIntegrationPlugin

@Test func packageLoads() async throws {
    #expect(EditorChatIntegrationPlugin.info.id == "EditorChatIntegration")
}

@MainActor
@Test func registersChatCommandContributor() async throws {
    let registry = EditorExtensionRegistry()

    await EditorChatIntegrationPlugin.registerEditorExtensions(into: registry)

    #expect(registry.commandContributorsCount == 1)
}

@Test func postsAddToChatNotification() async throws {
    await confirmation { posted in
        let observer = NotificationCenter.default.addObserver(
            forName: EditorChatIntegrationRuntime.addToChatNotificationName,
            object: nil,
            queue: nil
        ) { notification in
            if notification.userInfo?["text"] as? String == "hello" {
                posted()
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        EditorChatIntegrationRuntime.postAddToChat("hello")
    }
}

@Test func postsAddToChatNotificationWithWindowId() async throws {
    let windowId = UUID()

    await confirmation { posted in
        let observer = NotificationCenter.default.addObserver(
            forName: EditorChatIntegrationRuntime.addToChatNotificationName,
            object: nil,
            queue: nil
        ) { notification in
            if notification.userInfo?["text"] as? String == "hello",
               notification.userInfo?["windowId"] as? UUID == windowId {
                posted()
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        EditorChatIntegrationRuntime.postAddToChat("hello", windowId: windowId)
    }
}
