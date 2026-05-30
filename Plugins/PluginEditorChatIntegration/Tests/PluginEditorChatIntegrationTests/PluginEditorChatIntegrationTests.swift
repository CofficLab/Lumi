import Foundation
import Testing
import EditorService
@testable import PluginEditorChatIntegration

@Test func packageLoads() async throws {
    #expect(EditorChatIntegrationPlugin.id == "EditorChatIntegration")
}

@MainActor
@Test func registersChatCommandContributor() async throws {
    let plugin = EditorChatIntegrationPlugin.shared
    let registry = EditorExtensionRegistry()

    #expect(plugin.providesEditorExtensions)
    plugin.registerEditorExtensions(into: registry)

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
