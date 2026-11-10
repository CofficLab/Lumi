import LumiUI
import ProviderTheme
import SwiftUI
import Testing
@testable import LumiThemePack

/// ProviderTheme 的外观类型（与 LumiUI 同名，此处显式消歧）。
private typealias ProviderAppearanceKind = ProviderTheme.ThemeAppearanceKind

/// `LumiPaletteChromeTheme` 对 ProviderTheme 色板到 LumiUI chrome 契约的适配。
@Suite("色板适配器")
@MainActor
struct LumiPaletteChromeThemeTests {

    // MARK: - 元数据透传

    @Test("标识与展示字段原样透传")
    func metadataIsForwarded() {
        let theme = ThemeFixture.theme(
            id: "sample",
            displayName: "Sample",
            compactName: "S",
            description: "A sample theme"
        )
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)

        #expect(chrome.identifier == "sample")
        #expect(chrome.displayName == "Sample")
        #expect(chrome.compactName == "S")
        #expect(chrome.description == "A sample theme")
        #expect(chrome.iconName == "circle")
    }

    @Test("外观类型逐案映射到 LumiUI")
    func appearanceKindIsMapped() {
        func chrome(for kind: ProviderAppearanceKind) -> LumiUI.ThemeAppearanceKind {
            LumiPaletteChromeTheme(
                theme: ThemeFixture.theme(id: "x", appearanceKind: kind),
                colorScheme: .light
            ).appearanceKind
        }

        #expect(chrome(for: .dark) == .dark)
        #expect(chrome(for: .light) == .light)
        #expect(chrome(for: .system) == .system)
    }

    // MARK: - 语义色组

    @Test("强调色对应色板的 accent 三元组")
    func accentColorsMapToPalette() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)
        let accents = chrome.accentColors()

        #expect(accents.primary == theme.palette.accentPrimary.color(colorScheme: .light))
        #expect(accents.secondary == theme.palette.accentSecondary.color(colorScheme: .light))
        #expect(accents.tertiary == theme.palette.accentTertiary.color(colorScheme: .light))
    }

    @Test("氛围色对应背景三档")
    func atmosphereColorsMapToPalette() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .dark)
        let atmosphere = chrome.atmosphereColors()

        #expect(atmosphere.deep == theme.palette.backgroundDeep.color(colorScheme: .dark))
        #expect(atmosphere.medium == theme.palette.backgroundMedium.color(colorScheme: .dark))
        #expect(atmosphere.light == theme.palette.backgroundLight.color(colorScheme: .dark))
    }

    @Test("工作区文本色对应文本三档")
    func textColorsMapToPalette() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .dark)

        #expect(chrome.workspaceTextColor() == theme.palette.textPrimary.color(colorScheme: .dark))
        #expect(chrome.workspaceSecondaryTextColor() == theme.palette.textSecondary.color(colorScheme: .dark))
        #expect(chrome.workspaceTertiaryTextColor() == theme.palette.textTertiary.color(colorScheme: .dark))
    }

    @Test("侧栏与状态栏前景统一使用主文本色")
    func chromeForegroundsUsePrimaryText() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)
        let primaryText = theme.palette.textPrimary.color(colorScheme: .light)

        #expect(chrome.sidebarSelectionTextColor() == primaryText)
        #expect(chrome.statusBarForegroundColor() == primaryText)
        #expect(chrome.statusBarItemForegroundColor() == primaryText)
    }

    @Test("侧栏背景使用最深的背景档")
    func sidebarBackgroundUsesDeepestLayer() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)

        #expect(chrome.sidebarBackgroundColor() == theme.palette.backgroundDeep.color(colorScheme: .light))
    }

    @Test("展开与未展开的状态栏项返回不同底色")
    func statusBarItemBackgroundDependsOnPresentation() {
        let theme = ThemeFixture.theme(id: "x")
        let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)

        #expect(chrome.statusBarItemBackgroundColor(isPresented: true)
                != chrome.statusBarItemBackgroundColor(isPresented: false))
    }

    @Test("明暗外观解析出不同颜色")
    func colorSchemeChangesResolvedColors() {
        let theme = ThemeFixture.theme(id: "x")
        let light = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)
        let dark = LumiPaletteChromeTheme(theme: theme, colorScheme: .dark)

        #expect(light.accentColors().primary != dark.accentColors().primary)
        #expect(light.atmosphereColors().deep != dark.atmosphereColors().deep)
    }

    @Test("固定色主题在明暗外观下颜色一致")
    func fixedHexThemeIgnoresColorScheme() {
        let theme = ThemeFixture.theme(id: "x", singleHex: true)
        let light = LumiPaletteChromeTheme(theme: theme, colorScheme: .light)
        let dark = LumiPaletteChromeTheme(theme: theme, colorScheme: .dark)

        #expect(light.accentColors().primary == dark.accentColors().primary)
        #expect(light.atmosphereColors().deep == dark.atmosphereColors().deep)
    }

    @Test("适配真实目录主题不会崩溃且返回可渲染颜色")
    func adaptsEveryCatalogTheme() {
        for theme in LumiThemeCatalog.all {
            let chrome = LumiPaletteChromeTheme(theme: theme, colorScheme: .dark)
            _ = chrome.iconColor
            _ = chrome.accentColors()
            _ = chrome.atmosphereColors()
            _ = chrome.glowColors()
            #expect(chrome.identifier == theme.id)
        }
    }

    @Test("遵循系统外观的目录主题数量与注册表一致")
    func systemThemesAreReportedAsSystem() {
        let chromeThemes = LumiThemeCatalog.all.map {
            LumiPaletteChromeTheme(theme: $0, colorScheme: .light)
        }

        let systemCount = chromeThemes.filter { $0.appearanceKind == .system }.count
        let expected = LumiThemeCatalog.all.filter { $0.appearanceKind == .system }.count

        #expect(systemCount == expected)
        #expect(systemCount > 0)
    }
}
