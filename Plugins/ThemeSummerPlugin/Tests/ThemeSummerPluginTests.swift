import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeSummerPlugin

@MainActor
struct ThemeSummerPluginTests {
    @Test func metadata() {
        #expect(ThemeSummerPlugin.info.id == "com.coffic.lumi.plugin.theme.summer")
        #expect(ThemeSummerPlugin.info.displayName.isEmpty == false)
        #expect(ThemeSummerPlugin.info.order == 125)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSummerPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "summer")
        #expect(contributions[0].editorThemeId == "summer")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeSummerPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeSummerPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableOnLightSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: SummerTheme())
        #expect(
            SummerThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }

    @Test func workspaceTextRemainsReadableOnDarkSystemAppearance() {
        let ui = ChromeToUIThemeAdapter(chrome: SummerTheme())
        #expect(
            SummerThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .darkAqua)!
            )
        )
    }
}

private enum SummerThemeContrastTestSupport {
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
