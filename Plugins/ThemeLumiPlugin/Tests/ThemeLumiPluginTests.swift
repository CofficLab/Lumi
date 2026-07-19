import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeLumiPlugin

@MainActor
struct ThemeLumiPluginTests {
    @Test func metadata() {
        #expect(ThemeLumiPlugin.info.id == "com.coffic.lumi.plugin.theme.lumi")
        #expect(ThemeLumiPlugin.info.displayName.isEmpty == false)
        #expect(ThemeLumiPlugin.info.description.isEmpty == false)
        #expect(ThemeLumiPlugin.info.order == 100)
    }

    @Test func contributesTheme() {
        let contributions = ThemeLumiPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "lumi")
        #expect(contributions[0].editorThemeId == "lumi-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeLumiPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeLumiPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableOnLightSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: LumiTheme())
        #expect(
            LumiThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }

    @Test func workspaceTextRemainsReadableOnDarkSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: LumiTheme())
        #expect(
            LumiThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum LumiThemeContrastTestSupport {
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
