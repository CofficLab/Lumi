import EditorService
import LumiUI
import PluginThemeGithub

actor ThemeGithubPlugin: SuperPlugin {
    static let shared = ThemeGithubPlugin()
    static let id: String = PluginThemeGithub.ThemeGithubPlugin.id
    static let displayName: String = PluginThemeGithub.ThemeGithubPlugin.displayName
    static let description: String = PluginThemeGithub.ThemeGithubPlugin.description
    static let iconName: String = PluginThemeGithub.ThemeGithubPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeGithub.ThemeGithubPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeGithub.ThemeGithubPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeGithub.ThemeGithubPlugin.shared.registerEditorExtensions(into: registry)
    }
}
