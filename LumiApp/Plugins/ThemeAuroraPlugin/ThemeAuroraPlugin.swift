import Foundation

actor ThemeAuroraPlugin: SuperPlugin {
    static let shared = ThemeAuroraPlugin()
    static let id: String = "aurora"
    static let displayName: String = "Aurora"
    static let description: String = "Aurora purple app theme"
    static let iconName: String = "sparkles"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 121 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora",
                editorThemeContributor: AuroraSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.aurora()
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(AuroraSuperEditorThemeContributor())
    }

}
