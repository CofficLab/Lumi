import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import ThemeGithubPlugin

@MainActor
struct ThemeGithubPluginTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeGithubPlugin.id == "github")
        #expect(ThemeGithubPlugin.displayName == "GitHub")
        #expect(ThemeGithubPlugin.description.isEmpty == false)
        #expect(ThemeGithubPlugin.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(ThemeGithubPlugin.isConfigurable == false)
        #expect(ThemeGithubPlugin.category == .theme)
        #expect(ThemeGithubPlugin.order == 128)
        #expect(ThemeGithubPlugin.policy == .alwaysOn)
        #expect(ThemeGithubPlugin.shared.instanceLabel == ThemeGithubPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeGithubPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "github")
        #expect(contribution.displayName == "GitHub")
        #expect(contribution.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "github")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeGithubPlugin.shared.registerEditorExtensions(into: registry)
        ThemeGithubPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["github"])
    }

    @Test
    func githubThemeMetadataAndColorsAreStable() {
        let theme = GitHubTheme()

        #expect(theme.identifier == "github")
        #expect(theme.displayName == "GitHub")
        #expect(theme.compactName == "GitHub")
        #expect(theme.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(ThemeGithubPluginResources.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
    }
}
