import AppKit
import SwiftUI
import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeVscodeLightPlugin

@MainActor
struct ThemeVscodeLightPluginTests {
    @Test func metadata() {
        #expect(ThemeVscodeLightPlugin.info.id == "com.coffic.lumi.plugin.theme.vscode-light")
        #expect(ThemeVscodeLightPlugin.info.displayName.isEmpty == false)
        #expect(ThemeVscodeLightPlugin.info.order == 130)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeLightPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "vscode-light")
        #expect(contributions[0].editorThemeId == "vscode-light")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVscodeLightPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVscodeLightPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsDark() {
        let ui = ChromeToUIThemeAdapter(chrome: VscodeLightTheme())
        #expect(
            VscodeLightThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum VscodeLightThemeContrastTestSupport {
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
