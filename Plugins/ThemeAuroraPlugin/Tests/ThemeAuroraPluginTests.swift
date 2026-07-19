import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeAuroraPlugin

@MainActor
struct ThemeAuroraPluginTests {
    @Test func metadata() {
        #expect(ThemeAuroraPlugin.info.id == "com.coffic.lumi.plugin.theme.aurora")
        #expect(ThemeAuroraPlugin.info.displayName.isEmpty == false)
        #expect(ThemeAuroraPlugin.info.order == 121)
    }

    @Test func contributesTheme() {
        let contributions = ThemeAuroraPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "aurora")
        #expect(contributions[0].editorThemeId == "aurora")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeAuroraPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeAuroraPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let ui = ChromeToUIThemeAdapter(chrome: AuroraTheme())
        #expect(
            AuroraThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }
}

private enum AuroraThemeContrastTestSupport {
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
