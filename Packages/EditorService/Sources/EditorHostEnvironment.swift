import Foundation

/// Host-injected runtime configuration for `EditorService`.
/// Keeps the package business-agnostic and reusable across apps.
public struct EditorHostEnvironment: Sendable {
    public struct Notifications: Sendable {
        public var projectContextDidChange: Notification.Name
        public var settingsDidChange: Notification.Name
        public var themeDidChange: Notification.Name
        public var toggleOpenEditorsPanel: Notification.Name
        public var toggleOutlinePanel: Notification.Name
        public var showCommandPalette: Notification.Name
        public var triggerCompletion: Notification.Name
        public var triggerSignatureHelp: Notification.Name
        public var editorExtensionProvidersDidChange: Notification.Name

        public init(
            projectContextDidChange: Notification.Name = Notification.Name("EditorProjectContextDidChange"),
            settingsDidChange: Notification.Name = Notification.Name("EditorSettingsDidChange"),
            editorExtensionProvidersDidChange: Notification.Name = Notification.Name("EditorExtensionProvidersDidChange"),
            themeDidChange: Notification.Name = Notification.Name("EditorThemeDidChange"),
            toggleOpenEditorsPanel: Notification.Name = Notification.Name("EditorToggleOpenEditorsPanel"),
            toggleOutlinePanel: Notification.Name = Notification.Name("EditorToggleOutlinePanel"),
            showCommandPalette: Notification.Name = Notification.Name("EditorShowCommandPalette"),
            triggerCompletion: Notification.Name = Notification.Name("EditorTriggerCompletion"),
            triggerSignatureHelp: Notification.Name = Notification.Name("EditorTriggerSignatureHelp")
        ) {
            self.projectContextDidChange = projectContextDidChange
            self.settingsDidChange = settingsDidChange
            self.editorExtensionProvidersDidChange = editorExtensionProvidersDidChange
            self.themeDidChange = themeDidChange
            self.toggleOpenEditorsPanel = toggleOpenEditorsPanel
            self.toggleOutlinePanel = toggleOutlinePanel
            self.showCommandPalette = showCommandPalette
            self.triggerCompletion = triggerCompletion
            self.triggerSignatureHelp = triggerSignatureHelp
        }
    }

    public var logSubsystem: String
    public var localizationTable: String
    public var storageDirectoryName: String
    public var notifications: Notifications

    public init(
        logSubsystem: String = "EditorService",
        localizationTable: String = "EditorService",
        storageDirectoryName: String = "EditorService",
        notifications: Notifications = Notifications()
    ) {
        self.logSubsystem = logSubsystem
        self.localizationTable = localizationTable
        self.storageDirectoryName = storageDirectoryName
        self.notifications = notifications
    }

    nonisolated(unsafe) public static var current = EditorHostEnvironment()

    public static func configure(_ environment: EditorHostEnvironment) {
        self.current = environment
    }
}

