import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeRiverPlugin

@MainActor
struct ThemeRiverPluginTests {
    @Test func metadata() {
        #expect(ThemeRiverPlugin.info.id == "com.coffic.lumi.plugin.theme.river")
        #expect(ThemeRiverPlugin.info.displayName.isEmpty == false)
        #expect(ThemeRiverPlugin.info.order == 130)
    }

    @Test func contributesTheme() {
        let contributions = ThemeRiverPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "river")
        #expect(contributions[0].editorThemeId == "river")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeRiverPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeRiverPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableOnLightSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: RiverTheme())
        #expect(
            RiverThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }

    @Test func workspaceTextRemainsReadableOnDarkSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: RiverTheme())
        #expect(
            RiverThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum RiverThemeContrastTestSupport {
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
