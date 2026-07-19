import AppKit
import SwiftUI
import Testing
import LumiKernel
import LumiUI
@testable import ThemeGithubPlugin

@MainActor
struct ThemeGithubPluginTests {
    @Test func metadata() {
        #expect(ThemeGithubPlugin.info.id == "com.coffic.lumi.plugin.theme.github")
        #expect(ThemeGithubPlugin.info.displayName.isEmpty == false)
        #expect(ThemeGithubPlugin.info.order == 128)
    }

    @Test func contributesTheme() {
        let contributions = ThemeGithubPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "github")
        #expect(contributions[0].editorThemeId == "github")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeGithubPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeGithubPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }

    @Test func workspaceTextRemainsReadableWhenSystemAppearanceIsLight() {
        let ui = ChromeToUIThemeAdapter(chrome: GitHubTheme())
        #expect(
            GitHubThemeContrastTestSupport.hasSufficientContrast(
                text: ui.textPrimary,
                surface: ui.surface,
                systemAppearance: NSAppearance(named: .aqua)!
            )
        )
    }
}

private enum GitHubThemeContrastTestSupport {
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
