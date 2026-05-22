import Foundation

actor ThemeLumiPlugin: SuperPlugin {
    static let shared = ThemeLumiPlugin()
    static let id: String = "lumi"
    static let displayName: String = "Lumi"
    static let description: String = "Balanced default theme that adapts to system appearance"
    static let iconName: String = "circle.hexagonpath.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
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
                fileIconThemeContributor: LumiFileIconThemeCatalog.lumi()
            ),
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(LumiLightEditorThemeContributor())
    }
}
