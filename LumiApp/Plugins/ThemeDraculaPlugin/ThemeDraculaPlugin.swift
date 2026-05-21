import Foundation

actor ThemeDraculaPlugin: SuperPlugin {
    static let shared = ThemeDraculaPlugin()
    static let id: String = "dracula"
    static let displayName: String = "Dracula"
    static let description: String = "Dracula Official dark theme"
    static let iconName: String = "moon.stars.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 132 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: DraculaTheme(),
                editorThemeId: "dracula",
                editorThemeContributor: DraculaSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.dracula()
            )
        ]
    }
}
