import SwiftUI

/// Minimal built-in theme used when plugin-provided themes are unavailable.
public struct LumiFallbackChromeTheme: LumiAppChromeTheme {
    public let identifier = "lumi-fallback"
    public let displayName = "Lumi Fallback"
    public let compactName = "Lumi"
    public let description = "Built-in fallback theme for recovery when theme plugins are unavailable."
    public let iconName = "circle.hexagonpath.fill"
    public let iconColor = Color.adaptive(light: "007AFF", dark: "0A84FF")
    public let appearanceKind: ThemeAppearanceKind = .system

    public init() {}

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            primary: Color.adaptive(light: "007AFF", dark: "0A84FF"),
            secondary: Color.adaptive(light: "5856D6", dark: "5E5CE6"),
            tertiary: Color.adaptive(light: "34C759", dark: "30D158")
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            deep: Color.adaptive(light: "F2F2F7", dark: "000000"),
            medium: Color.adaptive(light: "FFFFFF", dark: "1C1C1E"),
            light: Color.adaptive(light: "E5E5EA", dark: "2C2C2E")
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (
            subtle: Color.adaptive(light: "007AFF", dark: "0A84FF").opacity(0.12),
            medium: Color.adaptive(light: "007AFF", dark: "0A84FF").opacity(0.22),
            intense: Color.adaptive(light: "5856D6", dark: "5E5CE6").opacity(0.35)
        )
    }

    public func workspaceBackgroundColor() -> Color {
        atmosphereColors().medium
    }

    public func sidebarBackgroundColor() -> Color {
        atmosphereColors().deep
    }

    public func workspaceTextColor() -> Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    public func workspaceSecondaryTextColor() -> Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.85)
    }

    public func workspaceTertiaryTextColor() -> Color {
        Color.adaptive(light: "98989E", dark: "98989E")
    }

    public func sidebarSelectionTextColor() -> Color {
        Color.white
    }
}

public extension LumiUIThemeContribution {
    static func builtInFallback() -> LumiUIThemeContribution {
        LumiUIThemeContribution(
            sortKey: ThemeSortKey(pluginOrder: Int.max, themeId: "lumi-fallback"),
            chromeTheme: LumiFallbackChromeTheme(),
            editorThemeId: "xcode-dark",
            uiTheme: LumiDefaultTheme()
        )
    }
}
