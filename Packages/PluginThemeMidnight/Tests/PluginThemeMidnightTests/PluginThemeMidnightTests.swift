import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import PluginThemeMidnight

@MainActor
struct PluginThemeMidnightTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeMidnightPlugin.id == "midnight")
        #expect(ThemeMidnightPlugin.displayName == "Midnight")
        #expect(ThemeMidnightPlugin.description.isEmpty == false)
        #expect(ThemeMidnightPlugin.iconName == "moon.stars.fill")
        #expect(ThemeMidnightPlugin.isConfigurable == false)
        #expect(ThemeMidnightPlugin.category == .theme)
        #expect(ThemeMidnightPlugin.order == 120)
        #expect(ThemeMidnightPlugin.enable == true)
        #expect(ThemeMidnightPlugin.shared.instanceLabel == ThemeMidnightPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeMidnightPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "midnight")
        #expect(contribution.displayName == "午夜幽蓝")
        #expect(contribution.iconName == "moon.stars.fill")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "midnight")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeMidnightPlugin.shared.registerEditorExtensions(into: registry)
        ThemeMidnightPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["midnight"])
    }

    @Test
    func midnightThemeMetadataAndColorsAreStable() {
        let theme = MidnightTheme()

        #expect(theme.identifier == "midnight")
        #expect(theme.displayName == "午夜幽蓝")
        #expect(theme.compactName == "午夜")
        #expect(theme.iconName == "moon.stars.fill")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginThemeMidnightResources.bundle.url(forResource: "ThemeMidnightPlugin", withExtension: "xcstrings") != nil)
    }
}
