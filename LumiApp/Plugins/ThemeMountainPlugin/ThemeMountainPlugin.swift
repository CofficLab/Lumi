import Foundation

actor ThemeMountainPlugin: SuperPlugin {
    static let shared = ThemeMountainPlugin()
    static let id: String = "mountain"
    static let displayName: String = "Mountain"
    static let description: String = "Mountain gray app theme"
    static let iconName: String = "mountain.2.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 129 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain",
                editorThemeContributor: MountainSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.mountain()
            )
        ]
    }
}
