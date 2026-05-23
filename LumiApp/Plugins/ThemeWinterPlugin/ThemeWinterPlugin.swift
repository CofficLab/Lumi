import Foundation

actor ThemeWinterPlugin: SuperPlugin {
    static let shared = ThemeWinterPlugin()
    static let id: String = "winter"
    static let displayName: String = "Winter"
    static let description: String = "Winter cool app theme"
    static let iconName: String = "snowflake"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
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
                fileIconThemeContributor: LumiFileIconThemeCatalog.winter()
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(WinterSuperEditorThemeContributor())
    }

}
