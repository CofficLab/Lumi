import AppKit
import LumiUI
import SwiftUI
import Testing
@testable import EditorBreadcrumbNavPlugin

/// 复现：VS Code 深色 + macOS 浅色系统时，面包屑图标几乎看不见。
///
/// 文字能看清是因为 `Text` 的 `foregroundColor` 往往仍会生效；`Menu` +
/// `.borderlessButton` 的 label 内 SF Symbol 常退回系统 `Color.primary`（单测测不到渲染，只能测色值策略）。
@MainActor
struct BreadcrumbNavIconContrastTests {
    @Test func breadcrumbSegmentUsesBorderlessMenuLabel() {
        #expect(BreadcrumbNavIconStyle.usesBorderlessMenuLabel)
    }

    @Test func systemPrimaryIconFailsContrastOnDarkBreadcrumbChromeUnderLightSystem() {
        let chrome = ForcedDarkBreadcrumbChromeFixture()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!

        let readable = BreadcrumbNavContrastTestSupport.hasSufficientContrast(
            text: Color.primary,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance
        )

        #expect(
            !readable,
            "Borderless Menu breadcrumb icons that fall back to Color.primary should expose the regression"
        )
    }

    @Test func declaredFolderIconColorPassesContrastOnDarkBreadcrumbChrome() {
        assertDeclaredIconPassesContrast(
            item: BreadcrumbItem(
                index: 0,
                name: "Plugins",
                url: URL(fileURLWithPath: "/tmp/project/Plugins"),
                isDirectory: true
            )
        )
    }

    @Test func declaredSwiftIconColorPassesContrastOnDarkBreadcrumbChrome() {
        assertDeclaredIconPassesContrast(
            item: BreadcrumbItem(
                index: 3,
                name: "AskUserPlugin.swift",
                url: URL(fileURLWithPath: "/tmp/project/Plugins/AskUserPlugin/Sources/AskUserPlugin.swift"),
                isDirectory: false
            )
        )
    }

    @Test func declaredGenericFileIconColorPassesContrastOnDarkBreadcrumbChrome() {
        assertDeclaredIconPassesContrast(
            item: BreadcrumbItem(
                index: 1,
                name: "README",
                url: URL(fileURLWithPath: "/tmp/project/README"),
                isDirectory: false
            )
        )
    }

    private func assertDeclaredIconPassesContrast(
        item: BreadcrumbItem,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let chrome = ForcedDarkBreadcrumbChromeFixture()
        let ui = ChromeToUIThemeAdapter(chrome: chrome)
        let lightAppearance = NSAppearance(named: .aqua)!
        let iconColor = BreadcrumbNavIconStyle.iconColor(for: item, theme: ui)

        let readable = BreadcrumbNavContrastTestSupport.hasSufficientContrast(
            text: iconColor,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance,
            minimumDelta: 0.15
        )
        let primaryReadable = BreadcrumbNavContrastTestSupport.hasSufficientContrast(
            text: Color.primary,
            surface: ui.elevatedSurface,
            systemAppearance: lightAppearance
        )

        #expect(
            readable,
            "Declared breadcrumb icon colors should contrast with dark chrome when actually applied",
            sourceLocation: sourceLocation
        )
        #expect(
            !primaryReadable || readable,
            "Declared icon color should be more readable than the borderless Menu primary fallback",
            sourceLocation: sourceLocation
        )
    }
}

private struct ForcedDarkBreadcrumbChromeFixture: LumiAppChromeTheme {
    let identifier = "forced-dark-breadcrumb"
    let displayName = "Forced Dark Breadcrumb"
    let compactName = "Dark"
    let description = "VS Code dark-like chrome for breadcrumb contrast tests"
    let iconName = "folder.fill"
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

private enum BreadcrumbNavContrastTestSupport {
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
