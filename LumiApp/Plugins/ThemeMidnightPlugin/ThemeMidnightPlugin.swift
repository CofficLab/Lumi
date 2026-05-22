import Foundation

actor ThemeMidnightPlugin: SuperPlugin {
    static let shared = ThemeMidnightPlugin()
    static let id: String = "midnight"
    static let displayName: String = "Midnight"
    static let description: String = "Deep dark blue color scheme"
    static let iconName: String = "moon.stars.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 120 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight",
                editorThemeContributor: MidnightSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.midnight()
            )
        ]
    }
}
