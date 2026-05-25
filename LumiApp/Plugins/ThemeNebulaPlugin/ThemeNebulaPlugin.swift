import Foundation

actor ThemeNebulaPlugin: SuperPlugin {
    static let shared = ThemeNebulaPlugin()
    static let id: String = "nebula"
    static let displayName: String = "星云粉"
    static let description: String = "浪漫的星云粉，柔和而温暖"
    static let iconName: String = "cloud.moon.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 122 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula",
                editorThemeContributor: NebulaSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "nebula-file-icons",
                    displayName: "Nebula File Icons",
                    defaultFile: .systemImage("circle.hexagongrid"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
                    extraExtensions: [
                        "swift": .systemImage("atom"),
                        "json": .systemImage("circle.hexagongrid.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(NebulaSuperEditorThemeContributor())
    }

}
