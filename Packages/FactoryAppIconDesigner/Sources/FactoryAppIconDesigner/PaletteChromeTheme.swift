import LumiUI
import ProviderTheme
import SwiftUI

/// 将 ProviderTheme 色板桥接到 LumiUI 的 Chrome 主题。
struct PaletteChromeTheme: LumiAppChromeTheme {
    private let theme: ProviderTheme.LumiTheme
    private let colorScheme: ColorScheme

    init(theme: ProviderTheme.LumiTheme, colorScheme: ColorScheme) {
        self.theme = theme
        self.colorScheme = colorScheme
    }

    var identifier: String { theme.id }
    var displayName: String { theme.displayName }
    var compactName: String { theme.compactName }
    var description: String { theme.description }
    var iconName: String { theme.iconName }
    var iconColor: Color { theme.iconColor.color(colorScheme: colorScheme) }

    var appearanceKind: LumiUI.ThemeAppearanceKind {
        switch theme.appearanceKind {
        case .dark: return .dark
        case .light: return .light
        case .system: return .system
        }
    }

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (
            primary: theme.palette.accentPrimary.color(colorScheme: colorScheme),
            secondary: theme.palette.accentSecondary.color(colorScheme: colorScheme),
            tertiary: theme.palette.accentTertiary.color(colorScheme: colorScheme)
        )
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (
            deep: theme.palette.backgroundDeep.color(colorScheme: colorScheme),
            medium: theme.palette.backgroundMedium.color(colorScheme: colorScheme),
            light: theme.palette.backgroundLight.color(colorScheme: colorScheme)
        )
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (
            subtle: theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.3),
            medium: theme.palette.accentSecondary.color(colorScheme: colorScheme).opacity(0.5),
            intense: theme.palette.accentTertiary.color(colorScheme: colorScheme).opacity(0.7)
        )
    }

    func workspaceTextColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func workspaceSecondaryTextColor() -> Color { theme.palette.textSecondary.color(colorScheme: colorScheme) }
    func workspaceTertiaryTextColor() -> Color { theme.palette.textTertiary.color(colorScheme: colorScheme) }
    func sidebarBackgroundColor() -> Color { theme.palette.backgroundDeep.color(colorScheme: colorScheme) }
    func sidebarSelectionColor() -> Color { theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.22) }
    func sidebarSelectionTextColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func statusBarForegroundColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func statusBarDividerColor() -> Color { theme.palette.textTertiary.color(colorScheme: colorScheme).opacity(0.18) }
    func statusBarItemBackgroundColor(isPresented: Bool) -> Color {
        isPresented
            ? theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.14)
            : theme.palette.textPrimary.color(colorScheme: colorScheme).opacity(0.08)
    }
    func statusBarItemForegroundColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
}
