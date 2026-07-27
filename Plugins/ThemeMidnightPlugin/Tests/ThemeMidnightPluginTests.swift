import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeMidnightPlugin

@MainActor
struct ThemeMidnightPluginTests {
    @Test func metadata() {
        #expect(ThemeMidnightPlugin.info.id == "com.coffic.lumi.plugin.theme.midnight")
        #expect(ThemeMidnightPlugin.info.displayName.isEmpty == false)
        #expect(ThemeMidnightPlugin.info.order == 120)
    }

    @Test func contributesTheme() {
        let contributions = ThemeMidnightPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "midnight")
        #expect(contributions[0].editorThemeId == "midnight")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeMidnightPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeMidnightPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let ui = ChromeToUIThemeAdapter(chrome: MidnightTheme())
        #expect(
            MidnightThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }
}

private enum MidnightThemeContrastTestSupport {
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
