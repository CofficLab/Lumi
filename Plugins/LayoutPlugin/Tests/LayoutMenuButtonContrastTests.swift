import AppKit
import LumiUI
import SwiftUI
import Testing
@testable import LayoutPlugin

/// 复现：VS Code 深色 + macOS 浅色系统时，右上角 Layout 菜单图标几乎看不见。
///
/// `AppTitleToolbar` 虽设置了 `.foregroundStyle(theme.textPrimary)`，但 `LayoutMenuButton`
/// 使用 `Menu` + `.menuStyle(.borderlessButton)`，标签图标往往仍解析为系统 `Color.primary`。
@MainActor
struct LayoutMenuButtonContrastTests {
    @Test func layoutMenuButtonReliesOnInheritedForeground() {
        #expect(LayoutMenuButton.usesExplicitIconForeground == false)
    }

    @Test func systemPrimaryIconFailsContrastOnDarkToolbarUnderLightSystem() {
        let chrome = ForcedDarkToolbarChromeFixture()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!

        // Toolbar sits on dark chrome; `appToolbarBackground` is a translucent tint and
        // does not composite in unit tests, so use the perceived chrome surface.
        let readable = LayoutMenuButtonContrastTestSupport.hasSufficientContrast(
            text: Color.primary,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance
        )

        #expect(
            !readable,
            "Borderless Menu icons that fall back to Color.primary should expose the regression"
        )
    }

    @Test func chromeTextPrimaryIconPassesContrastOnDarkToolbarUnderLightSystem() {
        let chrome = ForcedDarkToolbarChromeFixture()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!

        let readable = LayoutMenuButtonContrastTestSupport.hasSufficientContrast(
            text: ui.textPrimary,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance
        )

        #expect(
            readable,
            "Layout menu icon should use chrome textPrimary over dark toolbar chrome"
        )
    }
}

private struct ForcedDarkToolbarChromeFixture: LumiAppChromeTheme {
    let identifier = "forced-dark-toolbar"
    let displayName = "Forced Dark Toolbar"
    let compactName = "Dark"
    let description = "VS Code dark-like chrome for layout toolbar contrast tests"
    let iconName = "sidebar.leading"
    let iconColor = Color(hex: "007ACC")
    let appearanceKind: ThemeAppearanceKind = .dark

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (Color(hex: "007ACC"), Color(hex: "C586C0"), Color(hex: "D7BA7D"))
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (Color(hex: "1E1E1E"), Color(hex: "252526"), Color(hex: "2D2D2D"))
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.blue, .blue, .blue)
    }

    func workspaceTextColor() -> Color { Color(hex: "CCCCCC") }
    func workspaceSecondaryTextColor() -> Color { Color(hex: "969696") }
}

private enum LayoutMenuButtonContrastTestSupport {
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
        abs(
            perceptualLuminance(text, appearance: systemAppearance)
                - perceptualLuminance(surface, appearance: systemAppearance)
        ) >= minimumDelta
    }
}
