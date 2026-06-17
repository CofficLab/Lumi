import EditorService
import Foundation
import XcodeKit

enum EditorSwiftHostEnvironmentConfiguration {
    static func bridgeProjectContextNotificationName() -> Notification.Name {
        .lumiEditorProjectContextDidChange
    }

    @MainActor
    static func apply(using current: EditorHostEnvironment = EditorHostEnvironment.current) {
        let notifications = current.notifications
        EditorHostEnvironment.configure(
            EditorHostEnvironment(
                logSubsystem: current.logSubsystem,
                localizationTable: current.localizationTable,
                storageDirectoryName: current.storageDirectoryName,
                notifications: EditorHostEnvironment.Notifications(
                    projectContextDidChange: bridgeProjectContextNotificationName(),
                    settingsDidChange: notifications.settingsDidChange,
                    editorExtensionProvidersDidChange: notifications.editorExtensionProvidersDidChange,
                    themeDidChange: notifications.themeDidChange,
                    toggleOpenEditorsPanel: notifications.toggleOpenEditorsPanel,
                    toggleOutlinePanel: notifications.toggleOutlinePanel,
                    showCommandPalette: notifications.showCommandPalette,
                    triggerCompletion: notifications.triggerCompletion,
                    triggerSignatureHelp: notifications.triggerSignatureHelp
                )
            )
        )
    }
}
