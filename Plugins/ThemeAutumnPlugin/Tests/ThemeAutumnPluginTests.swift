import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import ThemeAutumnPlugin

@MainActor
struct ThemeAutumnPluginTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeAutumnPlugin.id == "autumn")
        #expect(ThemeAutumnPlugin.displayName == "Autumn")
        #expect(ThemeAutumnPlugin.description.isEmpty == false)
        #expect(ThemeAutumnPlugin.iconName == "leaf")
        #expect(ThemeAutumnPlugin.isConfigurable == false)
        #expect(ThemeAutumnPlugin.category == .theme)
        #expect(ThemeAutumnPlugin.order == 126)
        #expect(ThemeAutumnPlugin.policy == .alwaysOn)
        #expect(ThemeAutumnPlugin.shared.instanceLabel == ThemeAutumnPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeAutumnPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "autumn")
        #expect(contribution.displayName == "秋枫橙")
        #expect(contribution.iconName == "wind")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "autumn")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeAutumnPlugin.shared.registerEditorExtensions(into: registry)
        ThemeAutumnPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["autumn"])
    }

    @Test
    func autumnThemeMetadataAndColorsAreStable() {
        let theme = AutumnTheme()

        #expect(theme.identifier == "autumn")
        #expect(theme.displayName == "秋枫橙")
        #expect(theme.compactName == "秋")
        #expect(theme.iconName == "wind")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(ThemeAutumnPluginResources.bundle.url(forResource: "ThemeAutumnPlugin", withExtension: "xcstrings") != nil)
    }
}
