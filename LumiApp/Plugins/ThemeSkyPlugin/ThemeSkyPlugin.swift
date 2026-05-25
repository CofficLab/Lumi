import Foundation

actor ThemeSkyPlugin: SuperPlugin {
    static let shared = ThemeSkyPlugin()
    static let id: String = "sky"
    static let displayName: String = "Sky"
    static let description: String = "Sky inspired app theme that adapts to system appearance"
    static let iconName: String = "cloud.sun.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
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
                fileIconThemeContributor: LumiFileIconThemeCatalog.sky()
            ),
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(SkyDarkEditorThemeContributor())
        registry.registerThemeContributor(SkyLightEditorThemeContributor())
    }
}
