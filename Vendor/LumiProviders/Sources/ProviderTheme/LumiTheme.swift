import SwiftUI

// MARK: - Hex 颜色对

/// 一对 (亮色, 暗色) 十六进制颜色，按系统外观解析成 `Color`。
///
/// 采用字符串存储而非 `Color`，使模型保持 `Sendable` / `Equatable`，
/// 便于持久化与单元测试；渲染时再按有效外观解析为 `Color`。
public struct ThemeHexPair: Equatable, Sendable {
    /// 亮色外观下的十六进制色值（`RRGGBB` 或 `AARRGGBB`）。
    public let light: String
    /// 暗色外观下的十六进制色值（`RRGGBB` 或 `AARRGGBB`）。
    public let dark: String

    public init(light: String, dark: String) {
        self.light = light
        self.dark = dark
    }

    /// 构造固定色（亮 / 暗外观使用同一色值）。
    public init(hex: String) {
        self.light = hex
        self.dark = hex
    }

    /// 按当前有效外观解析为 SwiftUI `Color`。
    ///
    /// - Parameter colorScheme: 显式指定明暗；为 `nil` 时按系统当前外观解析。
    public func color(colorScheme: ColorScheme? = nil) -> Color {
        let isDark: Bool
        if let colorScheme {
            isDark = colorScheme == .dark
        } else {
            isDark = SystemAppearanceResolver.isDark
        }
        return Color(hex: isDark ? dark : light)
    }
}

// MARK: - 主题语义色板

/// 主题的完整语义色板。
///
/// 复刻旧版 Lumi（`LumiAppChromeTheme`）的核心语义色分组：
/// - accent：强调色（主 / 次 / 三级）
/// - atmosphere：氛围背景色（深 / 中 / 浅）
/// - text：文本色（主 / 次 / 三级）
public struct LumiThemePalette: Equatable, Sendable {
    public var accentPrimary: ThemeHexPair
    public var accentSecondary: ThemeHexPair
    public var accentTertiary: ThemeHexPair
    public var backgroundDeep: ThemeHexPair
    public var backgroundMedium: ThemeHexPair
    public var backgroundLight: ThemeHexPair
    public var textPrimary: ThemeHexPair
    public var textSecondary: ThemeHexPair
    public var textTertiary: ThemeHexPair

    public init(
        accentPrimary: ThemeHexPair,
        accentSecondary: ThemeHexPair,
        accentTertiary: ThemeHexPair,
        backgroundDeep: ThemeHexPair,
        backgroundMedium: ThemeHexPair,
        backgroundLight: ThemeHexPair,
        textPrimary: ThemeHexPair,
        textSecondary: ThemeHexPair,
        textTertiary: ThemeHexPair
    ) {
        self.accentPrimary = accentPrimary
        self.accentSecondary = accentSecondary
        self.accentTertiary = accentTertiary
        self.backgroundDeep = backgroundDeep
        self.backgroundMedium = backgroundMedium
        self.backgroundLight = backgroundLight
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
    }

    // MARK: - 便捷访问

    /// 强调色（主 / 次 / 三级）。
    public var accent: (primary: Color, secondary: Color, tertiary: Color) {
        (
            primary: accentPrimary.color(),
            secondary: accentSecondary.color(),
            tertiary: accentTertiary.color()
        )
    }

    /// 氛围背景色（深 / 中 / 浅）。
    public var atmosphere: (deep: Color, medium: Color, light: Color) {
        (
            deep: backgroundDeep.color(),
            medium: backgroundMedium.color(),
            light: backgroundLight.color()
        )
    }

    /// 文本色（主 / 次 / 三级）。
    public var text: (primary: Color, secondary: Color, tertiary: Color) {
        (
            primary: textPrimary.color(),
            secondary: textSecondary.color(),
            tertiary: textTertiary.color()
        )
    }
}

// MARK: - 主题模型

/// 可注册进 `ThemeProviding` 的完整主题。
///
/// 对应旧版 Lumi 的 `LumiUIThemeContribution`（展示字段）与
/// `LumiAppChromeTheme`（语义色）的合并：既包含主题列表展示所需的
/// 元数据，也包含消费方（工具栏 / 侧栏 / 内容区）渲染所需的语义色。
public struct LumiTheme: Identifiable, Equatable, Sendable {
    /// 主题唯一标识（如 `lumi-system`）。
    public let id: String
    /// 列表排序键：值越小越靠前，默认选中值最小的主题。
    public var sortOrder: Int
    /// 展示名称。
    public let displayName: String
    /// 紧凑名称（菜单等空间受限场景）。
    public let compactName: String
    /// 主题描述。
    public let description: String
    /// SF Symbol 名称（列表图标）。
    public let iconName: String
    /// 图标颜色。
    public let iconColor: ThemeHexPair
    /// 主题外观类型。
    public let appearanceKind: ThemeAppearanceKind
    /// 语义色板。
    public let palette: LumiThemePalette

    public init(
        id: String,
        sortOrder: Int = 100,
        displayName: String,
        compactName: String? = nil,
        description: String = "",
        iconName: String,
        iconColor: ThemeHexPair,
        appearanceKind: ThemeAppearanceKind,
        palette: LumiThemePalette
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.displayName = displayName
        self.compactName = compactName ?? displayName
        self.description = description
        self.iconName = iconName
        self.iconColor = iconColor
        self.appearanceKind = appearanceKind
        self.palette = palette
    }

    /// 图标颜色（按当前外观解析）。
    public var resolvedIconColor: Color {
        iconColor.color()
    }
}

// MARK: - Color 十六进制解析（内部）

extension Color {
    /// 解析 `RRGGBB` / `AARRGGBB` 十六进制色值。
    init(hex: String) {
        var value: UInt64 = 0
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        Scanner(string: hexString).scanHexInt64(&value)

        let r, g, b, a: Double
        switch hexString.count {
        case 8: // AARRGGBB
            a = Double((value >> 24) & 0xFF) / 255
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default: // RRGGBB
            a = 1
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - 系统外观解析

private enum SystemAppearanceResolver {
    static var isDark: Bool {
        #if canImport(AppKit)
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        #elseif canImport(UIKit)
        UITraitCollection.current.userInterfaceStyle == .dark
        #else
        false
        #endif
    }
}
