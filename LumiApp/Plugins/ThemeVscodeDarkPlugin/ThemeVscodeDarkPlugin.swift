import Foundation

actor ThemeVscodeDarkPlugin: SuperPlugin {
    static let shared = ThemeVscodeDarkPlugin()
    static let id: String = "vscode-dark"
    static let displayName: String = "VS Code 深色"
    static let description: String = "Visual Studio Code Dark+ IDE theme"
    static let iconName: String = "terminal.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 129 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark",
                editorThemeContributor: VscodeDarkSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.vscodeDark()
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VscodeDarkSuperEditorThemeContributor())
    }

}
