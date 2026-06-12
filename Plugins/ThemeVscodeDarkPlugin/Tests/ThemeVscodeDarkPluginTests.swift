import AppKit
import SwiftUI
import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeVscodeDarkPlugin

@MainActor
struct ThemeVscodeDarkPluginTests {
    @Test func metadata() {
        #expect(ThemeVscodeDarkPlugin.info.id == "com.coffic.lumi.plugin.theme.vscode-dark")
        #expect(ThemeVscodeDarkPlugin.info.displayName.isEmpty == false)
        #expect(ThemeVscodeDarkPlugin.info.order == 129)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeDarkPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "vscode-dark")
        #expect(contributions[0].editorThemeId == "vscode-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVscodeDarkPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVscodeDarkPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    /// 复现：macOS 浅色模式下选 VS Code 深色 → 背景固定暗色、文字走 adaptive 浅色变体，对比度崩溃。
    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let chrome = VscodeDarkTheme()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!

        #expect(
            VscodeDarkThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: lightAppearance
            ),
            "Forced-dark chrome themes must keep readable text on their surfaces when macOS is in light mode"
        )
    }
}

private enum VscodeDarkThemeContrastTestSupport {
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
        let textLuminance = perceptualLuminance(text, appearance: systemAppearance)
        let surfaceLuminance = perceptualLuminance(surface, appearance: systemAppearance)
        return abs(textLuminance - surfaceLuminance) >= minimumDelta
    }
}
