import Foundation

actor ThemeRiverPlugin: SuperPlugin {
    static let shared = ThemeRiverPlugin()
    static let id: String = "river"
    static let displayName: String = "River"
    static let description: String = "River cyan app theme"
    static let iconName: String = "water.waves"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 130 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: RiverTheme(),
                editorThemeId: "river",
                editorThemeContributor: RiverSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.river()
            )
        ]
    }
}
