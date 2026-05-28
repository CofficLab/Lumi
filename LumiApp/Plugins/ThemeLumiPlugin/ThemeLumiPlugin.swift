import Foundation

actor ThemeLumiPlugin: SuperPlugin {
    static let shared = ThemeLumiPlugin()
    static let id: String = "lumi"
    static let displayName: String = "Lumi"
    static let description: String = "Balanced default theme that adapts to system appearance"
    static let iconName: String = "circle.hexagonpath.fill"
    static var category: PluginCategory { .theme }
    static var order: Int { 119 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: LumiTheme(),
                editorThemeId: "lumi-dark",
                editorThemeContributor: LumiDarkEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "lumi-file-icons",
                    displayName: "Lumi File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "md": .systemImage("text.alignleft"),
                        "json": .systemImage("curlybraces"),
                    ]
                )
            ),
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(LumiDarkEditorThemeContributor())
        registry.registerThemeContributor(LumiLightEditorThemeContributor())
    }
}
