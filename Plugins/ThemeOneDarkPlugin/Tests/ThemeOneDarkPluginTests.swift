import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeOneDarkPlugin

@MainActor
struct ThemeOneDarkPluginTests {
    @Test func metadata() {
        #expect(ThemeOneDarkPlugin.info.id == "com.coffic.lumi.plugin.theme.one-dark")
        #expect(ThemeOneDarkPlugin.info.displayName.isEmpty == false)
        #expect(ThemeOneDarkPlugin.info.order == 131)
    }

    @Test func contributesTheme() {
        let contributions = ThemeOneDarkPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "one-dark")
        #expect(contributions[0].editorThemeId == "one-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeOneDarkPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeOneDarkPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let ui = ChromeToUIThemeAdapter(chrome: OneDarkTheme())
        #expect(
            OneDarkThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }
}

private enum OneDarkThemeContrastTestSupport {
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
        abs(perceptualLuminance(text, appearance: systemAppearance) - perceptualLuminance(surface, appearance: systemAppearance)) >= minimumDelta
    }
}
