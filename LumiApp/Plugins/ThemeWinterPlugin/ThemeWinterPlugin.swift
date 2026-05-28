import Foundation

actor ThemeWinterPlugin: SuperPlugin {
    static let shared = ThemeWinterPlugin()
    static let id: String = "winter"
    static let displayName: String = "Winter"
    static let description: String = "Winter cool app theme"
    static let iconName: String = "snowflake"
    static var category: PluginCategory { .theme }
    static var order: Int { 127 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter",
                editorThemeContributor: WinterSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "winter-file-icons",
                    displayName: "Winter File Icons",
                    defaultFile: .systemImage("snowflake"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
                    extraExtensions: [
                        "sh": .systemImage("terminal.fill"),
                        "bash": .systemImage("terminal.fill"),
                        "zsh": .systemImage("terminal.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(WinterSuperEditorThemeContributor())
    }

}
