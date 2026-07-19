import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeDraculaPlugin

@MainActor
struct ThemeDraculaPluginTests {
    @Test func metadata() {
        #expect(ThemeDraculaPlugin.info.id == "com.coffic.lumi.plugin.theme.dracula")
        #expect(ThemeDraculaPlugin.info.displayName.isEmpty == false)
        #expect(ThemeDraculaPlugin.info.order == 132)
    }

    @Test func contributesTheme() {
        let contributions = ThemeDraculaPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "dracula")
        #expect(contributions[0].editorThemeId == "dracula")
    }

    @Test func editorSyntaxPaletteMatchesDraculaPreset() {
        let palette = DraculaTheme().editorSyntaxPalette(colorScheme: .dark)
        #expect(palette.backgroundHex == "282A36")
        #expect(palette.keywords.colorHex == "FF79C6")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeDraculaPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeDraculaPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let ui = ChromeToUIThemeAdapter(chrome: DraculaTheme())
        #expect(
            DraculaThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }
}

private enum DraculaThemeContrastTestSupport {
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
