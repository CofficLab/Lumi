import Foundation

actor ThemeAutumnPlugin: SuperPlugin {
    static let shared = ThemeAutumnPlugin()
    static let id: String = "autumn"
    static let displayName: String = "Autumn"
    static let description: String = "Autumn orange app theme"
    static let iconName: String = "leaf"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 126 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn",
                editorThemeContributor: AutumnSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.autumn()
            )
        ]
    }
}
