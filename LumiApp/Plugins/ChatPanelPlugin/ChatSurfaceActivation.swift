enum ChatSurfaceActivation {
    static func isActive(_ activeIcon: String?) -> Bool {
        activeIcon == EditorPlugin.iconName || activeIcon == ChatPanelPlugin.iconName
    }
}
