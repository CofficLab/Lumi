import AppKit
import LumiUI
import SwiftUI
import Testing
@testable import EditorSwiftPlugin

@MainActor
struct XcodeProjectStatusBarContrastTests {
    @Test func titleToolbarTextPassesContrastOnVscodeLightToolbar() {
        let ui = ChromeToUIThemeAdapter(chrome: VscodeLightThemeFixture())
        let lightAppearance = NSAppearance(named: .aqua)!
        let toolbarSurface = ui.elevatedSurface

        let primaryReadable = XcodeProjectStatusBarContrastTestSupport.hasSufficientContrast(
            text: XcodeProjectStatusBar.titleToolbarPrimaryTextColor(theme: ui),
            surface: toolbarSurface,
            systemAppearance: lightAppearance
        )
        let secondaryReadable = XcodeProjectStatusBarContrastTestSupport.hasSufficientContrast(
            text: XcodeProjectStatusBar.titleToolbarSecondaryTextColor(theme: ui),
            surface: toolbarSurface,
            systemAppearance: lightAppearance
        )

        #expect(primaryReadable)
        #expect(secondaryReadable)
    }

    @Test func statusBarForegroundWouldFailOnLightToolbar() {
        let ui = ChromeToUIThemeAdapter(chrome: VscodeLightThemeFixture())
        let lightAppearance = NSAppearance(named: .aqua)!

        let readable = XcodeProjectStatusBarContrastTestSupport.hasSufficientContrast(
            text: ui.statusBarItemForeground,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance
        )

        #expect(!readable)
    }
}

private struct VscodeLightThemeFixture: LumiAppChromeTheme {
    let identifier = "vscode-light-fixture"
    let displayName = "VS Code Light"
    let compactName = "VSCode亮"
    let description = "Fixture"
    let iconName = "terminal"
    let iconColor = Color(hex: "007ACC")
    let appearanceKind: ThemeAppearanceKind = .light

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (Color(hex: "007ACC"), Color(hex: "A31515"), Color(hex: "795E26"))
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (Color(hex: "F3F3F3"), Color(hex: "FFFFFF"), Color(hex: "E8E8E8"))
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.blue, .blue, .blue)
    }

    func workspaceTextColor() -> Color { Color(hex: "333333") }
    func workspaceSecondaryTextColor() -> Color { Color(hex: "6A6A6A") }
    func statusBarItemForegroundColor() -> Color { .white }
}

private enum XcodeProjectStatusBarContrastTestSupport {
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
