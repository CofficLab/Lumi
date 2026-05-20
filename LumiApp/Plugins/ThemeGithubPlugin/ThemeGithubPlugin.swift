import Foundation

actor ThemeGithubPlugin: SuperPlugin {
    static let shared = ThemeGithubPlugin()
    static let id: String = "github"
    static let displayName: String = "GitHub"
    static let description: String = "GitHub style app theme"
    static let iconName: String = "chevron.left.forwardslash.chevron.right"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 128 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: GitHubTheme(),
                editorThemeId: "github",
                editorThemeContributor: GithubSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.github(),
                order: 85
            )
        ]
    }
}
