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
        // 将 EditorService 日志子系统固定为 com.coffic.lumi，确保被 FileLogCoordinator 持久化到磁盘
        // （符合 .agent/rules/swift-log.md：所有日志子系统统一为 com.coffic.lumi）
        EditorHostEnvironment.configure(
            EditorHostEnvironment(
                logSubsystem: "com.coffic.lumi",
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
