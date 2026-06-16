import EditorService
import Foundation
import Testing
import XcodeKit
@testable import EditorSwiftPlugin

@Test func swiftPluginProjectContextNotificationMatchesBridge() {
    #expect(
        EditorSwiftHostEnvironmentConfiguration.bridgeProjectContextNotificationName()
        == Notification.Name.lumiEditorProjectContextDidChange
    )
}

@Test @MainActor func swiftPluginConfiguresEditorHostEnvironmentNotification() {
    let previous = EditorHostEnvironment.current
    defer { EditorHostEnvironment.configure(previous) }

    EditorSwiftHostEnvironmentConfiguration.apply()

    #expect(
        EditorHostEnvironment.current.notifications.projectContextDidChange
        == Notification.Name.lumiEditorProjectContextDidChange
    )
}
