import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeWinterPlugin

@MainActor
struct ThemeWinterPluginTests {
    @Test func metadata() {
        #expect(ThemeWinterPlugin.info.id == "com.coffic.lumi.plugin.theme.winter")
        #expect(ThemeWinterPlugin.info.displayName.isEmpty == false)
        #expect(ThemeWinterPlugin.info.order == 127)
    }

    @Test func contributesTheme() {
        let contributions = ThemeWinterPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "winter")
        #expect(contributions[0].editorThemeId == "winter")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeWinterPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeWinterPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableOnLightSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: WinterTheme())
        #expect(
            WinterThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }

    @Test func workspaceTextRemainsReadableOnDarkSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: WinterTheme())
        #expect(
            WinterThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum WinterThemeContrastTestSupport {
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
