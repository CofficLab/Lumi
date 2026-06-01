import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import PluginThemeNebula

@MainActor
struct PluginThemeNebulaTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeNebulaPlugin.id == "nebula")
        #expect(ThemeNebulaPlugin.displayName == "星云粉")
        #expect(ThemeNebulaPlugin.description == "浪漫的星云粉，柔和而温暖")
        #expect(ThemeNebulaPlugin.iconName == "cloud.moon.fill")
        #expect(ThemeNebulaPlugin.isConfigurable == false)
        #expect(ThemeNebulaPlugin.category == .theme)
        #expect(ThemeNebulaPlugin.order == 122)
        #expect(ThemeNebulaPlugin.policy == .alwaysOn)
        #expect(ThemeNebulaPlugin.shared.instanceLabel == ThemeNebulaPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeNebulaPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "nebula")
        #expect(contribution.displayName == "星云粉")
        #expect(contribution.iconName == "cloud.moon.fill")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "nebula")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeNebulaPlugin.shared.registerEditorExtensions(into: registry)
        ThemeNebulaPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["nebula"])
    }

    @Test
    func nebulaThemeMetadataAndColorsAreStable() {
        let theme = NebulaTheme()

        #expect(theme.identifier == "nebula")
        #expect(theme.displayName == "星云粉")
        #expect(theme.compactName == "星云")
        #expect(theme.iconName == "cloud.moon.fill")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginThemeNebulaResources.bundle.url(forResource: "ThemeNebulaPlugin", withExtension: "xcstrings") != nil)
    }
}
