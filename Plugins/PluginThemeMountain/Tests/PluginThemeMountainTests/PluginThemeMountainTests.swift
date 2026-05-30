import EditorService
import Foundation
import LumiCoreKit
import LumiUI
import Testing
@testable import PluginThemeMountain

@MainActor
struct PluginThemeMountainTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(ThemeMountainPlugin.id == "mountain")
        #expect(ThemeMountainPlugin.displayName == "Mountain")
        #expect(ThemeMountainPlugin.description.isEmpty == false)
        #expect(ThemeMountainPlugin.iconName == "mountain.2.fill")
        #expect(ThemeMountainPlugin.isConfigurable == false)
        #expect(ThemeMountainPlugin.category == .theme)
        #expect(ThemeMountainPlugin.order == 129)
        #expect(ThemeMountainPlugin.enable == true)
        #expect(ThemeMountainPlugin.shared.instanceLabel == ThemeMountainPlugin.id)
    }

    @Test
    func themeContributionIsComplete() {
        let contributions = ThemeMountainPlugin.shared.addThemeContributions()

        #expect(contributions.count == 1)
        let contribution = contributions[0]
        #expect(contribution.id == "mountain")
        #expect(contribution.displayName == "山岚灰")
        #expect(contribution.iconName == "mountain.2.fill")
        #expect(contribution.appearanceKind == .dark)
        #expect(contribution.editorThemeId == "mountain")
        #expect(contribution.attachments.editorThemeContributor != nil)
        #expect(contribution.attachments.fileIconThemeContributor != nil)
    }

    @Test
    func editorThemeContributorRegistersOnce() {
        let registry = EditorExtensionRegistry()

        ThemeMountainPlugin.shared.registerEditorExtensions(into: registry)
        ThemeMountainPlugin.shared.registerEditorExtensions(into: registry)

        #expect(registry.allThemes().map(\.id) == ["mountain"])
    }

    @Test
    func mountainThemeMetadataAndColorsAreStable() {
        let theme = MountainTheme()

        #expect(theme.identifier == "mountain")
        #expect(theme.displayName == "山岚灰")
        #expect(theme.compactName == "山")
        #expect(theme.iconName == "mountain.2.fill")
        #expect(theme.appearanceKind == .dark)

        _ = theme.accentColors()
        _ = theme.atmosphereColors()
        _ = theme.glowColors()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginThemeMountainResources.bundle.url(forResource: "ThemeMountainPlugin", withExtension: "xcstrings") != nil)
    }
}
