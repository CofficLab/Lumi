import Foundation

actor ThemeOneDarkPlugin: SuperPlugin {
    static let shared = ThemeOneDarkPlugin()
    static let id: String = "one-dark"
    static let displayName: String = "One Dark"
    static let description: String = "Atom One Dark classic dark theme"
    static let iconName: String = "circle.hexagongrid"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 131 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OneDarkTheme(),
                editorThemeId: "one-dark",
                editorThemeContributor: OneDarkSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.oneDark()
            )
        ]
    }
}
