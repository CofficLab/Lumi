import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeGithubPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeGithubPlugin()
    public static let id: String = "github"
    public static let displayName: String = "GitHub"
    public static let description: String = "GitHub style app theme"
    public static let iconName: String = "chevron.left.forwardslash.chevron.right"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 128 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
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
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(GithubSuperEditorThemeContributor())
    }

}

enum ThemeGithubPluginResources {
    static let bundle = Bundle.module
}
