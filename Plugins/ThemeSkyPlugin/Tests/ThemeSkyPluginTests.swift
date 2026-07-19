import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeSkyPlugin

@MainActor
struct ThemeSkyPluginTests {
    @Test func metadata() {
        #expect(ThemeSkyPlugin.info.id == "com.coffic.lumi.plugin.theme.sky")
        #expect(ThemeSkyPlugin.info.displayName.isEmpty == false)
        #expect(ThemeSkyPlugin.info.order == 120)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSkyPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "sky")
        #expect(contributions[0].editorThemeId == "sky-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeSkyPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeSkyPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableOnLightSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: SkyTheme())
        #expect(
            SkyThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }

    @Test func workspaceTextRemainsReadableOnDarkSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: SkyTheme())
        #expect(
            SkyThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum SkyThemeContrastTestSupport {
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
