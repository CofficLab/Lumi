import Foundation

actor ThemeSkyPlugin: SuperPlugin {
    static let shared = ThemeSkyPlugin()
    static let id: String = "sky"
    static let displayName: String = "Sky"
    static let description: String = "Sky inspired app theme that adapts to system appearance"
    static let iconName: String = "cloud.sun.fill"
    static var category: PluginCategory { .theme }
    static var order: Int { 120 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SkyTheme(),
                editorThemeId: "sky-dark",
                editorThemeContributor: SkyDarkEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "sky-file-icons",
                    displayName: "Sky File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "md": .systemImage("cloud"),
                        "markdown": .systemImage("cloud"),
                        "json": .systemImage("curlybraces"),
                        "png": .systemImage("photo"),
                        "jpg": .systemImage("photo"),
                        "jpeg": .systemImage("photo"),
                    ]
                )
            ),
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(SkyDarkEditorThemeContributor())
        registry.registerThemeContributor(SkyLightEditorThemeContributor())
    }
}
