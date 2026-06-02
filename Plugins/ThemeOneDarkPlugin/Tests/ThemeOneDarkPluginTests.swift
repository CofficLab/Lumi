import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import ThemeOneDarkPlugin

@MainActor
struct ThemeOneDarkPluginTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeOneDarkPlugin.id == "one-dark")
        #expect(ThemeOneDarkPlugin.displayName == "One Dark")
        #expect(ThemeOneDarkPlugin.description == "Atom One Dark classic dark theme")
        #expect(ThemeOneDarkPlugin.iconName == "circle.hexagongrid")
        #expect(ThemeOneDarkPlugin.isConfigurable == false)
        #expect(ThemeOneDarkPlugin.category == .theme)
        #expect(ThemeOneDarkPlugin.order == 131)
        #expect(ThemeOneDarkPlugin.policy == .alwaysOn)
        #expect(ThemeOneDarkPlugin.shared.instanceLabel == ThemeOneDarkPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeOneDarkPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "one-dark")
        #expect(contribution.displayName == "One Dark")
        #expect(contribution.iconName == "circle.hexagongrid")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "one-dark")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeOneDarkPlugin.shared.registerEditorExtensions(into: registry)
        ThemeOneDarkPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["one-dark"])
    }

    @Test
    func oneDarkThemeMetadataAndColorsAreStable() {
        let theme = OneDarkTheme()

        #expect(theme.identifier == "one-dark")
        #expect(theme.displayName == "One Dark")
        #expect(theme.compactName == "One Dark")
        #expect(theme.iconName == "circle.hexagongrid")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(ThemeOneDarkPluginResources.bundle.url(forResource: "ThemeOneDarkPlugin", withExtension: "xcstrings") != nil)
    }
}
