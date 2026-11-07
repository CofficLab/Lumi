import LumiUI
import ProviderTheme
import SwiftUI

/// Adapts a shared theme palette to LumiUI's chrome theme contract.
public struct LumiPaletteChromeTheme: LumiAppChromeTheme {
    private let theme: ProviderTheme.LumiTheme
    private let colorScheme: ColorScheme

    public init(theme: ProviderTheme.LumiTheme, colorScheme: ColorScheme) {
        self.theme = theme
        self.colorScheme = colorScheme
    }

    public var identifier: String { theme.id }
    public var displayName: String { theme.displayName }
    public var compactName: String { theme.compactName }
    public var description: String { theme.description }
    public var iconName: String { theme.iconName }
    public var iconColor: Color { theme.iconColor.color(colorScheme: colorScheme) }

    public var appearanceKind: LumiUI.ThemeAppearanceKind {
        switch theme.appearanceKind {
        case .dark: return .dark
        case .light: return .light
        case .system: return .system
        }
    }

    public func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            primary: theme.palette.accentPrimary.color(colorScheme: colorScheme),
            secondary: theme.palette.accentSecondary.color(colorScheme: colorScheme),
            tertiary: theme.palette.accentTertiary.color(colorScheme: colorScheme)
        )
    }

    public func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            deep: theme.palette.backgroundDeep.color(colorScheme: colorScheme),
            medium: theme.palette.backgroundMedium.color(colorScheme: colorScheme),
            light: theme.palette.backgroundLight.color(colorScheme: colorScheme)
        )
    }

    public func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (
            subtle: theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.3),
            medium: theme.palette.accentSecondary.color(colorScheme: colorScheme).opacity(0.5),
            intense: theme.palette.accentTertiary.color(colorScheme: colorScheme).opacity(0.7)
        )
    }

    public func workspaceTextColor() -> Color {
        theme.palette.textPrimary.color(colorScheme: colorScheme)
    }

    public func workspaceSecondaryTextColor() -> Color {
        theme.palette.textSecondary.color(colorScheme: colorScheme)
    }

    public func workspaceTertiaryTextColor() -> Color {
        theme.palette.textTertiary.color(colorScheme: colorScheme)
    }

    public func sidebarBackgroundColor() -> Color {
        theme.palette.backgroundDeep.color(colorScheme: colorScheme)
    }

    public func sidebarSelectionColor() -> Color {
        theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.22)
    }

    public func sidebarSelectionTextColor() -> Color {
        theme.palette.textPrimary.color(colorScheme: colorScheme)
    }

    public func statusBarForegroundColor() -> Color {
        theme.palette.textPrimary.color(colorScheme: colorScheme)
    }

    public func statusBarDividerColor() -> Color {
        theme.palette.textTertiary.color(colorScheme: colorScheme).opacity(0.18)
    }

    public func statusBarItemBackgroundColor(isPresented: Bool) -> Color {
        isPresented
            ? theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.14)
            : theme.palette.textPrimary.color(colorScheme: colorScheme).opacity(0.08)
    }

    public func statusBarItemForegroundColor() -> Color {
        theme.palette.textPrimary.color(colorScheme: colorScheme)
    }
}
