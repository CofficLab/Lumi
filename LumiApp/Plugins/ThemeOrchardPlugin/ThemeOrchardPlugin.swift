import Foundation

actor ThemeOrchardPlugin: SuperPlugin {
    static let shared = ThemeOrchardPlugin()
    static let id: String = "orchard"
    static let displayName: String = "Orchard"
    static let description: String = "Orchard red app theme"
    static let iconName: String = "applelogo"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 128 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OrchardTheme(),
                editorThemeId: "orchard",
                editorThemeContributor: OrchardSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.orchard()
            )
        ]
    }
}
