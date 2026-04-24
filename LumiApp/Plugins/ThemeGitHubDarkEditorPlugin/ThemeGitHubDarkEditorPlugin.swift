import Foundation

@objc(LumiThemeGitHubDarkEditorPlugin)
@MainActor
final class ThemeGitHubDarkEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.github-dark"
    let displayName: String = String(localized: "GitHub Dark Theme", table: "ThemeGitHubDarkEditor")
    override var description: String { String(localized: "GitHub's official dark color scheme", table: "ThemeGitHubDarkEditor") }
    let order: Int = 109
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeGitHubDarkContributor())
    }
}
