import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import PluginThemeAurora

@MainActor
struct PluginThemeAuroraTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeAuroraPlugin.id == "aurora")
        #expect(ThemeAuroraPlugin.displayName == "Aurora")
        #expect(ThemeAuroraPlugin.description.isEmpty == false)
        #expect(ThemeAuroraPlugin.iconName == "sparkles")
        #expect(ThemeAuroraPlugin.isConfigurable == false)
        #expect(ThemeAuroraPlugin.category == .theme)
        #expect(ThemeAuroraPlugin.order == 121)
        #expect(ThemeAuroraPlugin.policy == .alwaysOn)
        #expect(ThemeAuroraPlugin.shared.instanceLabel == ThemeAuroraPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeAuroraPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "aurora")
        #expect(contribution.displayName == "极光紫")
        #expect(contribution.compactName == "极光")
        #expect(contribution.iconName == "sparkles")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "aurora")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeAuroraPlugin.shared.registerEditorExtensions(into: registry)
        ThemeAuroraPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["aurora"])
    }

    @Test
    func auroraThemeMetadataAndColorsAreStable() {
        let theme = AuroraTheme()

        #expect(theme.identifier == "aurora")
        #expect(theme.displayName == "极光紫")
        #expect(theme.compactName == "极光")
        #expect(theme.iconName == "sparkles")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginThemeAuroraResources.bundle.url(forResource: "ThemeAuroraPlugin", withExtension: "xcstrings") != nil)
    }
}
