import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeVscodePlugin

@MainActor
struct ThemeVscodePluginTests {
    // MARK: - Plugin Metadata

    @Test func metadata() {
        #expect(ThemeVscodePlugin.info.id == "com.coffic.lumi.plugin.theme.vscode")
        #expect(ThemeVscodePlugin.info.displayName.isEmpty == false)
        #expect(ThemeVscodePlugin.info.order == 129)
    }

    @Test func contributesThreeThemes() {
        let contributions = ThemeVscodePlugin.themeContributions()
        #expect(contributions.count == 3)
    }

    @Test func contributesAutoTheme() {
        let contributions = ThemeVscodePlugin.themeContributions()
        let auto = contributions.first { $0.id == "vscode-auto" }
        #expect(auto != nil)
        #expect(auto?.editorThemeId == "vscode-auto")
        #expect(auto?.appearanceKind == .system)
    }

    @Test func contributesDarkTheme() {
        let contributions = ThemeVscodePlugin.themeContributions()
        let dark = contributions.first { $0.id == "vscode-dark" }
        #expect(dark != nil)
        #expect(dark?.editorThemeId == "vscode-dark")
        #expect(dark?.appearanceKind == .dark)
    }

    @Test func contributesLightTheme() {
        let contributions = ThemeVscodePlugin.themeContributions()
        let light = contributions.first { $0.id == "vscode-light" }
        #expect(light != nil)
        #expect(light?.editorThemeId == "vscode-light")
        #expect(light?.appearanceKind == .light)
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVscodePlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVscodePlugin.info.id)
        #expect(provider?.themeContributions().count == 3)
    }

    // MARK: - Auto Theme Resolution

    @Test func autoThemeResolvesToDarkInDarkMode() {
        let theme = VscodeAutoTheme()
        let resolved = theme.resolvedEditorThemeId(
            defaultEditorThemeId: "vscode-auto",
            colorScheme: .dark
        )
        #expect(resolved == "vscode-dark")
    }

    @Test func autoThemeResolvesToLightInLightMode() {
        let theme = VscodeAutoTheme()
        let resolved = theme.resolvedEditorThemeId(
            defaultEditorThemeId: "vscode-auto",
            colorScheme: .light
        )
        #expect(resolved == "vscode-light")
    }

    // MARK: - Contrast Tests

    @Test func darkThemeTextReadableWhenSystemIsLight() {
        let chrome = VscodeDarkTheme()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!

        #expect(
            ContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: lightAppearance
            ),
            "Forced-dark chrome themes must keep readable text when macOS is in light mode"
        )
    }

    @Test func lightThemeTextReadableWhenSystemIsDark() {
        let ui = ChromeToUIThemeAdapter(chrome: VscodeLightTheme())
        #expect(
            ContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum ContrastTestSupport {
    static func perceptualLuminance(_ color: Color, appearance: NSAppearance) -> Double {
        let saved = NSAppearance.current
        NSAppearance.current = appearance
        defer { NSAppearance.current = saved }
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }

    static func hasSufficientContrast(
        text: Color,
        surface: Color,
        systemAppearance: NSAppearance,
        minimumDelta: Double = 0.25
    ) -> Bool {
        let textLuminance = perceptualLuminance(text, appearance: systemAppearance)
        let surfaceLuminance = perceptualLuminance(surface, appearance: systemAppearance)
        return abs(textLuminance - surfaceLuminance) >= minimumDelta
    }
}
