import Foundation

/// 内置主题集合。
///
/// 提供开箱即用的三个基础主题（跟随系统 / 固定暗色 / 固定亮色），
/// 配色参考旧版 Lumi 的 `LumiFallbackChromeTheme`。`DefaultThemeProviding`
/// 初始化时默认注册全部内置主题，宿主亦可替换。
public enum BuiltinThemes {
    /// 内置主题列表（按展示顺序）。
    public static let all: [LumiTheme] = [
        system,
        dark,
        light,
    ]

    /// 跟随系统明暗（默认选中）。
    public static let system = LumiTheme(
        id: "lumi-system",
        sortOrder: 100,
        displayName: "System",
        compactName: "System",
        description: "Follows the system light / dark appearance.",
        iconName: "circle.lefthalf.filled",
        iconColor: ThemeHexPair(light: "007AFF", dark: "0A84FF"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "007AFF", dark: "0A84FF"),
            accentSecondary: ThemeHexPair(light: "5856D6", dark: "5E5CE6"),
            accentTertiary: ThemeHexPair(light: "34C759", dark: "30D158"),
            backgroundDeep: ThemeHexPair(light: "F2F2F7", dark: "000000"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "1C1C1E"),
            backgroundLight: ThemeHexPair(light: "E5E5EA", dark: "2C2C2E"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "98989E")
        )
    )

    /// 固定暗色。
    public static let dark = LumiTheme(
        id: "lumi-dark",
        sortOrder: 200,
        displayName: "Dark",
        compactName: "Dark",
        description: "A fixed dark appearance.",
        iconName: "moon.fill",
        iconColor: ThemeHexPair(hex: "0A84FF"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "0A84FF"),
            accentSecondary: ThemeHexPair(hex: "5E5CE6"),
            accentTertiary: ThemeHexPair(hex: "30D158"),
            backgroundDeep: ThemeHexPair(hex: "000000"),
            backgroundMedium: ThemeHexPair(hex: "1C1C1E"),
            backgroundLight: ThemeHexPair(hex: "2C2C2E"),
            textPrimary: ThemeHexPair(hex: "FFFFFF"),
            textSecondary: ThemeHexPair(hex: "EBEBF5"),
            textTertiary: ThemeHexPair(hex: "98989E")
        )
    )

    /// 固定亮色。
    public static let light = LumiTheme(
        id: "lumi-light",
        sortOrder: 300,
        displayName: "Light",
        compactName: "Light",
        description: "A fixed light appearance.",
        iconName: "sun.max.fill",
        iconColor: ThemeHexPair(hex: "007AFF"),
        appearanceKind: .light,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "007AFF"),
            accentSecondary: ThemeHexPair(hex: "5856D6"),
            accentTertiary: ThemeHexPair(hex: "34C759"),
            backgroundDeep: ThemeHexPair(hex: "F2F2F7"),
            backgroundMedium: ThemeHexPair(hex: "FFFFFF"),
            backgroundLight: ThemeHexPair(hex: "E5E5EA"),
            textPrimary: ThemeHexPair(hex: "1C1C1E"),
            textSecondary: ThemeHexPair(hex: "6B6B7B"),
            textTertiary: ThemeHexPair(hex: "98989E")
        )
    )
}
