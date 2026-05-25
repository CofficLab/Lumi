import Foundation

actor ThemeGithubPlugin: SuperPlugin {
    static let shared = ThemeGithubPlugin()
    static let id: String = "github"
    static let displayName: String = "GitHub"
    static let description: String = "GitHub style app theme"
    static let iconName: String = "chevron.left.forwardslash.chevron.right"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 128 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: GitHubTheme(),
                editorThemeId: "github",
                editorThemeContributor: GithubSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "github-file-icons",
                    displayName: "GitHub File Icons",
                    defaultFile: .systemImage("doc"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraFolders: [
                        ".github": LumiFileIconThemeBuilder.folder("point.3.connected.trianglepath.dotted", "point.3.connected.trianglepath.dotted"),
                    ],
                    extraFileNames: [
                        ".gitignore": .systemImage("arrow.triangle.branch"),
                        ".gitattributes": .systemImage("arrow.triangle.branch"),
                        ".gitmodules": .systemImage("arrow.triangle.branch"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(GithubSuperEditorThemeContributor())
    }

}
