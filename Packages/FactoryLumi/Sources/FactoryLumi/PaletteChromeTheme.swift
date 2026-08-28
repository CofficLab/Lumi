import LumiUI
import ProviderTheme
import SwiftUI

/// 把新版主题（`ProviderTheme.LumiTheme` 的语义色板）适配为旧版 chrome 主题
/// （`LumiUI.LumiAppChromeTheme`），让 LumiUI 组件在设置窗口渲染出与旧版
/// 完全一致的颜色（背景、氛围渐变、文本、强调色）。
///
/// 旧版 Lumi 的主题由各插件直接实现 `LumiAppChromeTheme`；新版统一收敛为
/// `LumiThemePalette`（accent / atmosphere / text 三组语义色）。本适配器
/// 在宿主（FactoryLumi）层把 palette 桥接回 chrome 主题，使
/// `@LumiTheme`（`ChromeToUIThemeAdapter`）与 `ChromeThemes.current`
/// （`mystiqueBackground` 等）都能读到正确颜色，视觉与旧版设置窗口一致。
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
        return (
            subtle: theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.3),
            medium: theme.palette.accentSecondary.color(colorScheme: colorScheme).opacity(0.5),
            intense: theme.palette.accentTertiary.color(colorScheme: colorScheme).opacity(0.7)
        )
    }

    func workspaceTextColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func workspaceSecondaryTextColor() -> Color { theme.palette.textSecondary.color(colorScheme: colorScheme) }
    func workspaceTertiaryTextColor() -> Color { theme.palette.textTertiary.color(colorScheme: colorScheme) }
    func sidebarBackgroundColor() -> Color { theme.palette.backgroundDeep.color(colorScheme: colorScheme) }
    func sidebarSelectionColor() -> Color {
        theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.22)
    }
    func sidebarSelectionTextColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func statusBarForegroundColor() -> Color { theme.palette.textPrimary.color(colorScheme: colorScheme) }
    func statusBarDividerColor() -> Color {
        theme.palette.textTertiary.color(colorScheme: colorScheme).opacity(0.18)
    }
    func statusBarItemBackgroundColor(isPresented: Bool) -> Color {
        isPresented
            ? theme.palette.accentPrimary.color(colorScheme: colorScheme).opacity(0.14)
            : theme.palette.textPrimary.color(colorScheme: colorScheme).opacity(0.08)
    }
    func statusBarItemForegroundColor() -> Color {
        theme.palette.textPrimary.color(colorScheme: colorScheme)
    }
}
