import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import ThemeDraculaPlugin

@MainActor
struct ThemeDraculaPluginTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeDraculaPlugin.id == "dracula")
        #expect(ThemeDraculaPlugin.displayName == "Dracula")
        #expect(ThemeDraculaPlugin.description.isEmpty == false)
        #expect(ThemeDraculaPlugin.iconName == "moon.stars.fill")
        #expect(ThemeDraculaPlugin.isConfigurable == false)
        #expect(ThemeDraculaPlugin.category == .theme)
        #expect(ThemeDraculaPlugin.order == 132)
        #expect(ThemeDraculaPlugin.policy == .alwaysOn)
        #expect(ThemeDraculaPlugin.shared.instanceLabel == ThemeDraculaPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeDraculaPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "dracula")
        #expect(contribution.displayName == "Dracula")
        #expect(contribution.iconName == "moon.stars.fill")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "dracula")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeDraculaPlugin.shared.registerEditorExtensions(into: registry)
        ThemeDraculaPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["dracula"])
    }

    @Test
    func draculaThemeMetadataAndColorsAreStable() {
        let theme = DraculaTheme()

        #expect(theme.identifier == "dracula")
        #expect(theme.displayName == "Dracula")
        #expect(theme.compactName == "Dracula")
        #expect(theme.iconName == "moon.stars.fill")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(ThemeDraculaPluginResources.bundle.url(forResource: "ThemeDraculaPlugin", withExtension: "xcstrings") != nil)
    }
}
