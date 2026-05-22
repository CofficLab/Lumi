import Foundation

actor ThemeSpringPlugin: SuperPlugin {
    static let shared = ThemeSpringPlugin()
    static let id: String = "spring"
    static let displayName: String = "Spring"
    static let description: String = "Spring green app theme"
    static let iconName: String = "leaf.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 124 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SpringTheme(),
                editorThemeId: "spring",
                editorThemeContributor: SpringSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.spring()
            )
        ]
    }
}
