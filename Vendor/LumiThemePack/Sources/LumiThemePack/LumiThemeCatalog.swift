import Foundation
import ProviderTheme

// MARK: - 旧版 Lumi 主题色板复刻目录
//
// 复刻自 LumiApp 的 17 个主题插件（Plugins/Theme*Plugin）：
// 每个 `LumiAppChromeTheme` 的语义色板被转录为 ProviderTheme 的
// `LumiTheme` 值类型。id 保持旧值（如 "lumi" / "dracula"），
// 使已持久化的主题选择（theme-selection.plist）跨 App 兼容。
//
// 文本色：仅旧版显式定义 `workspaceTextColor` 等的主题转录其值；
// 其余主题沿用 `LumiAppChromeTheme` 协议默认值
// （primary 1C1C1E/FFFFFF、secondary 6B6B7B/EBEBF5、tertiary 98989E/EBEBF5）。

/// 旧版主题插件的复刻目录（19 个主题贡献）。
public enum LumiThemeCatalog {
    /// 全部复刻主题，按旧版插件 order（100 → 132）升序排列。
    public static let all: [LumiTheme] = [
        lumi,
        midnight,
        sky,
        aurora,
        nebula,
        void,
        spring,
        summer,
        autumn,
        winter,
        github,
        orchard,
        mountain,
        vscodeAuto,
        vscodeDark,
        vscodeLight,
        river,
        oneDark,
        dracula,
    ]

    // MARK: - Lumi 森林墨（ThemeLumiPlugin, order 100）

    public static let lumi = LumiTheme(
        id: "lumi",
        sortOrder: 1000,
        displayName: LumiThemePackLocalization.string("Lumi", bundle: .module),
        compactName: LumiThemePackLocalization.string("Lumi", bundle: .module),
        description: LumiThemePackLocalization.string("Forest Ink · low-saturation warm palette, adapts to system light and dark", bundle: .module),
        iconName: "circle.hexagonpath.fill",
        iconColor: ThemeHexPair(light: "059669", dark: "34D399"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "059669", dark: "34D399"),
            accentSecondary: ThemeHexPair(light: "D97706", dark: "F59E0B"),
            accentTertiary: ThemeHexPair(light: "0EA5E9", dark: "38BDF8"),
            backgroundDeep: ThemeHexPair(light: "FAFAF9", dark: "1C1C1A"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "262624"),
            backgroundLight: ThemeHexPair(light: "E7E5E4", dark: "30302E"),
            textPrimary: ThemeHexPair(light: "1C1917", dark: "FAFAF9"),
            textSecondary: ThemeHexPair(light: "57534E", dark: "D6D3D1"),
            textTertiary: ThemeHexPair(light: "A8A29E", dark: "A8A29E")
        )
    )

    // MARK: - 午夜幽蓝（ThemeMidnightPlugin, order 120）

    public static let midnight = LumiTheme(
        id: "midnight",
        sortOrder: 1010,
        displayName: LumiThemePackLocalization.string("Midnight Blue", bundle: .module),
        compactName: LumiThemePackLocalization.string("Midnight", bundle: .module),
        description: LumiThemePackLocalization.string("Deep midnight blue, mysterious and serene", bundle: .module),
        iconName: "moon.stars.fill",
        iconColor: ThemeHexPair(hex: "5B4FCF"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "5B4FCF"),
            accentSecondary: ThemeHexPair(hex: "7C6FFF"),
            accentTertiary: ThemeHexPair(light: "00B4D8", dark: "00D4FF"),
            backgroundDeep: ThemeHexPair(light: "F5F5FA", dark: "050510"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "0A0A1F"),
            backgroundLight: ThemeHexPair(light: "E8E8F2", dark: "151530"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 天空（ThemeSkyPlugin, order 120）

    public static let sky = LumiTheme(
        id: "sky",
        sortOrder: 1020,
        displayName: LumiThemePackLocalization.string("Sky", bundle: .module),
        compactName: LumiThemePackLocalization.string("Sky", bundle: .module),
        description: LumiThemePackLocalization.string("Between clear sky and night, follows the system appearance", bundle: .module),
        iconName: "cloud.sun.fill",
        iconColor: ThemeHexPair(light: "0EA5E9", dark: "93C5FD"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "0284C7", dark: "60A5FA"),
            accentSecondary: ThemeHexPair(light: "F59E0B", dark: "FACC15"),
            accentTertiary: ThemeHexPair(light: "14B8A6", dark: "38BDF8"),
            backgroundDeep: ThemeHexPair(light: "EAF7FF", dark: "07111F"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "0D1B2E"),
            backgroundLight: ThemeHexPair(light: "D7ECFF", dark: "162A44"),
            textPrimary: ThemeHexPair(light: "102033", dark: "EAF6FF"),
            textSecondary: ThemeHexPair(light: "4B647A", dark: "B6C8DA"),
            textTertiary: ThemeHexPair(light: "7890A3", dark: "7F97AF")
        )
    )

    // MARK: - 极光紫（ThemeAuroraPlugin, order 121）

    public static let aurora = LumiTheme(
        id: "aurora",
        sortOrder: 1030,
        displayName: LumiThemePackLocalization.string("Aurora Purple", bundle: .module),
        compactName: LumiThemePackLocalization.string("Aurora", bundle: .module),
        description: LumiThemePackLocalization.string("Gorgeous aurora purple, dreamy and elegant", bundle: .module),
        iconName: "sparkles",
        iconColor: ThemeHexPair(light: "8B5CF6", dark: "A78BFA"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "8B5CF6", dark: "A78BFA"),
            accentSecondary: ThemeHexPair(light: "0EA5E9", dark: "38BDF8"),
            accentTertiary: ThemeHexPair(light: "10B981", dark: "34D399"),
            backgroundDeep: ThemeHexPair(light: "F8F5FF", dark: "0A0515"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "120A20"),
            backgroundLight: ThemeHexPair(light: "F3E8FF", dark: "1F1535"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 星云粉（ThemeNebulaPlugin, order 122）

    public static let nebula = LumiTheme(
        id: "nebula",
        sortOrder: 1040,
        displayName: LumiThemePackLocalization.string("Nebula Pink", bundle: .module),
        compactName: LumiThemePackLocalization.string("Nebula", bundle: .module),
        description: LumiThemePackLocalization.string("Romantic nebula pink, soft and warm", bundle: .module),
        iconName: "cloud.moon.fill",
        iconColor: ThemeHexPair(light: "DB2777", dark: "F472B6"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "DB2777", dark: "F472B6"),
            accentSecondary: ThemeHexPair(light: "E11D48", dark: "FB7185"),
            accentTertiary: ThemeHexPair(light: "9333EA", dark: "C084FC"),
            backgroundDeep: ThemeHexPair(light: "FFF0F5", dark: "10050A"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "1F0A15"),
            backgroundLight: ThemeHexPair(light: "FFE4E9", dark: "301020"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 虚空深黑（ThemeVoidPlugin, order 123）

    public static let void = LumiTheme(
        id: "void",
        sortOrder: 1050,
        displayName: LumiThemePackLocalization.string("Void Black", bundle: .module),
        compactName: LumiThemePackLocalization.string("Void", bundle: .module),
        description: LumiThemePackLocalization.string("Pure void black, deep and mysterious", bundle: .module),
        iconName: "circle.fill",
        iconColor: ThemeHexPair(light: "4F46E5", dark: "6366F1"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "4F46E5", dark: "6366F1"),
            accentSecondary: ThemeHexPair(light: "7C3AED", dark: "8B5CF6"),
            accentTertiary: ThemeHexPair(light: "DB2777", dark: "EC4899"),
            backgroundDeep: ThemeHexPair(light: "F9FAFB", dark: "020205"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "080810"),
            backgroundLight: ThemeHexPair(light: "E5E7EB", dark: "101018"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 春芽绿（ThemeSpringPlugin, order 124）

    public static let spring = LumiTheme(
        id: "spring",
        sortOrder: 1060,
        displayName: LumiThemePackLocalization.string("Spring Bud Green", bundle: .module),
        compactName: LumiThemePackLocalization.string("Spring", bundle: .module),
        description: LumiThemePackLocalization.string("Fresh spring buds awakening, crisp and gentle", bundle: .module),
        iconName: "leaf.fill",
        iconColor: ThemeHexPair(light: "15803D", dark: "7CCF7A"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "15803D", dark: "7CCF7A"),
            accentSecondary: ThemeHexPair(light: "DB2777", dark: "F9A8D4"),
            accentTertiary: ThemeHexPair(light: "2563EB", dark: "60A5FA"),
            backgroundDeep: ThemeHexPair(light: "F2FBF5", dark: "07110A"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "0D1A10"),
            backgroundLight: ThemeHexPair(light: "E6F4EA", dark: "13251A"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 盛夏蓝（ThemeSummerPlugin, order 125）

    public static let summer = LumiTheme(
        id: "summer",
        sortOrder: 1070,
        displayName: LumiThemePackLocalization.string("Midsummer Blue", bundle: .module),
        compactName: LumiThemePackLocalization.string("Summer", bundle: .module),
        description: LumiThemePackLocalization.string("Blazing sun and sea breeze, clear and bright", bundle: .module),
        iconName: "sun.max.fill",
        iconColor: ThemeHexPair(light: "0284C7", dark: "38BDF8"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "0284C7", dark: "38BDF8"),
            accentSecondary: ThemeHexPair(light: "CA8A04", dark: "FACC15"),
            accentTertiary: ThemeHexPair(light: "059669", dark: "34D399"),
            backgroundDeep: ThemeHexPair(light: "F0F9FF", dark: "041018"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "082030"),
            backgroundLight: ThemeHexPair(light: "E0F2FE", dark: "0F2F3F"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 秋枫橙（ThemeAutumnPlugin, order 126）

    public static let autumn = LumiTheme(
        id: "autumn",
        sortOrder: 1080,
        displayName: LumiThemePackLocalization.string("Autumn Maple Orange", bundle: .module),
        compactName: LumiThemePackLocalization.string("Autumn", bundle: .module),
        description: LumiThemePackLocalization.string("Slight red maple shade, warm and profound", bundle: .module),
        iconName: "wind",
        iconColor: ThemeHexPair(light: "EA580C", dark: "F97316"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "EA580C", dark: "F97316"),
            accentSecondary: ThemeHexPair(light: "B91C1C", dark: "DC2626"),
            accentTertiary: ThemeHexPair(light: "854D0E", dark: "A16207"),
            backgroundDeep: ThemeHexPair(light: "FFF7ED", dark: "160B05"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "2A1408"),
            backgroundLight: ThemeHexPair(light: "FFEDD5", dark: "3A1F0F"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 霜冬白（ThemeWinterPlugin, order 127）

    public static let winter = LumiTheme(
        id: "winter",
        sortOrder: 1090,
        displayName: LumiThemePackLocalization.string("Frost Winter White", bundle: .module),
        compactName: LumiThemePackLocalization.string("Winter", bundle: .module),
        description: LumiThemePackLocalization.string("Frost and snow glow, calm and serene", bundle: .module),
        iconName: "snowflake",
        iconColor: ThemeHexPair(light: "2563EB", dark: "60A5FA"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "2563EB", dark: "60A5FA"),
            accentSecondary: ThemeHexPair(light: "93C5FD", dark: "E0F2FE"),
            accentTertiary: ThemeHexPair(light: "6366F1", dark: "A5B4FC"),
            backgroundDeep: ThemeHexPair(light: "F8FAFC", dark: "060B16"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "0D1424"),
            backgroundLight: ThemeHexPair(light: "F1F5F9", dark: "16203A"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - GitHub（ThemeGithubPlugin, order 128）

    public static let github = LumiTheme(
        id: "github",
        sortOrder: 1100,
        displayName: LumiThemePackLocalization.string("GitHub", bundle: .module),
        compactName: LumiThemePackLocalization.string("GitHub", bundle: .module),
        description: LumiThemePackLocalization.string("Inspired by GitHub's dark theme, deep and professional", bundle: .module),
        iconName: "chevron.left.forwardslash.chevron.right",
        iconColor: ThemeHexPair(light: "24292E", dark: "58A6FF"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "1F6FEB", dark: "58A6FF"),
            accentSecondary: ThemeHexPair(light: "238636", dark: "3FB950"),
            accentTertiary: ThemeHexPair(light: "A371F7", dark: "BC8CFF"),
            backgroundDeep: ThemeHexPair(light: "F6F8FA", dark: "0D1117"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "161B22"),
            backgroundLight: ThemeHexPair(light: "E1E4E8", dark: "21262D"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 果园红（ThemeOrchardPlugin, order 128）

    public static let orchard = LumiTheme(
        id: "orchard",
        sortOrder: 1110,
        displayName: LumiThemePackLocalization.string("Orchard Red", bundle: .module),
        compactName: LumiThemePackLocalization.string("Orchard", bundle: .module),
        description: LumiThemePackLocalization.string("Fruity sweetness, bright and vivid", bundle: .module),
        iconName: "apple.logo",
        iconColor: ThemeHexPair(light: "E11D48", dark: "F43F5E"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "E11D48", dark: "F43F5E"),
            accentSecondary: ThemeHexPair(light: "EA580C", dark: "F97316"),
            accentTertiary: ThemeHexPair(light: "65A30D", dark: "84CC16"),
            backgroundDeep: ThemeHexPair(light: "FFF5F7", dark: "14070B"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "1F0D12"),
            backgroundLight: ThemeHexPair(light: "FFE4E6", dark: "2B1118"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - 山岚灰（ThemeMountainPlugin, order 129）

    public static let mountain = LumiTheme(
        id: "mountain",
        sortOrder: 1120,
        displayName: LumiThemePackLocalization.string("Mountain Mist Gray", bundle: .module),
        compactName: LumiThemePackLocalization.string("Mountain", bundle: .module),
        description: LumiThemePackLocalization.string("Steady stone gray, distant pine shadows", bundle: .module),
        iconName: "mountain.2.fill",
        iconColor: ThemeHexPair(light: "475569", dark: "64748B"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "475569", dark: "64748B"),
            accentSecondary: ThemeHexPair(light: "64748B", dark: "94A3B8"),
            accentTertiary: ThemeHexPair(light: "16A34A", dark: "22C55E"),
            backgroundDeep: ThemeHexPair(light: "F1F5F9", dark: "0A0C10"),
            backgroundMedium: ThemeHexPair(light: "E2E8F0", dark: "12161D"),
            backgroundLight: ThemeHexPair(light: "CBD5E1", dark: "1C2230"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - VS Code 自适应（ThemeVscodePlugin, order 129）

    public static let vscodeAuto = LumiTheme(
        id: "vscode-auto",
        sortOrder: 1130,
        displayName: LumiThemePackLocalization.string("VS Code", bundle: .module),
        compactName: LumiThemePackLocalization.string("VSCode", bundle: .module),
        description: LumiThemePackLocalization.string("Automatically switches VS Code light/dark palette with the system appearance", bundle: .module),
        iconName: "terminal",
        iconColor: ThemeHexPair(hex: "007ACC"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "007ACC"),
            accentSecondary: ThemeHexPair(light: "A31515", dark: "C586C0"),
            accentTertiary: ThemeHexPair(light: "795E26", dark: "D7BA7D"),
            backgroundDeep: ThemeHexPair(light: "F3F3F3", dark: "1E1E1E"),
            backgroundMedium: ThemeHexPair(light: "FFFFFF", dark: "252526"),
            backgroundLight: ThemeHexPair(light: "E8E8E8", dark: "2D2D2D"),
            textPrimary: ThemeHexPair(light: "333333", dark: "CCCCCC"),
            textSecondary: ThemeHexPair(light: "6A6A6A", dark: "969696"),
            textTertiary: ThemeHexPair(light: "999999", dark: "6A6A6A")
        )
    )

    // MARK: - VS Code 深色（ThemeVscodePlugin, order 129）

    public static let vscodeDark = LumiTheme(
        id: "vscode-dark",
        sortOrder: 1140,
        displayName: LumiThemePackLocalization.string("VS Code Dark", bundle: .module),
        compactName: LumiThemePackLocalization.string("VSCode Dark", bundle: .module),
        description: LumiThemePackLocalization.string("Classic dark IDE palette of Visual Studio Code Dark+", bundle: .module),
        iconName: "terminal.fill",
        iconColor: ThemeHexPair(hex: "007ACC"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "007ACC"),
            accentSecondary: ThemeHexPair(hex: "C586C0"),
            accentTertiary: ThemeHexPair(hex: "D7BA7D"),
            backgroundDeep: ThemeHexPair(hex: "1E1E1E"),
            backgroundMedium: ThemeHexPair(hex: "252526"),
            backgroundLight: ThemeHexPair(hex: "2D2D2D"),
            textPrimary: ThemeHexPair(hex: "CCCCCC"),
            textSecondary: ThemeHexPair(hex: "969696"),
            textTertiary: ThemeHexPair(hex: "6A6A6A")
        )
    )

    // MARK: - VS Code 亮色（ThemeVscodePlugin, order 129）

    public static let vscodeLight = LumiTheme(
        id: "vscode-light",
        sortOrder: 1150,
        displayName: LumiThemePackLocalization.string("VS Code Light", bundle: .module),
        compactName: LumiThemePackLocalization.string("VSCode Light", bundle: .module),
        description: LumiThemePackLocalization.string("Classic light IDE palette of Visual Studio Code Light+", bundle: .module),
        iconName: "terminal",
        iconColor: ThemeHexPair(hex: "007ACC"),
        appearanceKind: .light,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "007ACC"),
            accentSecondary: ThemeHexPair(hex: "A31515"),
            accentTertiary: ThemeHexPair(hex: "795E26"),
            backgroundDeep: ThemeHexPair(hex: "F3F3F3"),
            backgroundMedium: ThemeHexPair(hex: "FFFFFF"),
            backgroundLight: ThemeHexPair(hex: "E8E8E8"),
            textPrimary: ThemeHexPair(hex: "333333"),
            textSecondary: ThemeHexPair(hex: "6A6A6A"),
            textTertiary: ThemeHexPair(hex: "999999")
        )
    )

    // MARK: - 河流青（ThemeRiverPlugin, order 130）

    public static let river = LumiTheme(
        id: "river",
        sortOrder: 1160,
        displayName: LumiThemePackLocalization.string("River Teal", bundle: .module),
        compactName: LumiThemePackLocalization.string("River", bundle: .module),
        description: LumiThemePackLocalization.string("Clear ripples, pure and translucent", bundle: .module),
        iconName: "drop.fill",
        iconColor: ThemeHexPair(light: "0284C7", dark: "0EA5E9"),
        appearanceKind: .system,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(light: "0284C7", dark: "0EA5E9"),
            accentSecondary: ThemeHexPair(light: "0891B2", dark: "22D3EE"),
            accentTertiary: ThemeHexPair(light: "059669", dark: "10B981"),
            backgroundDeep: ThemeHexPair(light: "F0F9FF", dark: "04111A"),
            backgroundMedium: ThemeHexPair(light: "E0F2FE", dark: "0A1E2B"),
            backgroundLight: ThemeHexPair(light: "BAE6FD", dark: "0F2A3A"),
            textPrimary: ThemeHexPair(light: "1C1C1E", dark: "FFFFFF"),
            textSecondary: ThemeHexPair(light: "6B6B7B", dark: "EBEBF5"),
            textTertiary: ThemeHexPair(light: "98989E", dark: "EBEBF5")
        )
    )

    // MARK: - One Dark（ThemeOneDarkPlugin, order 131）

    public static let oneDark = LumiTheme(
        id: "one-dark",
        sortOrder: 1170,
        displayName: LumiThemePackLocalization.string("One Dark", bundle: .module),
        compactName: LumiThemePackLocalization.string("One Dark", bundle: .module),
        description: LumiThemePackLocalization.string("Classic Atom One Dark palette, comfortable and balanced", bundle: .module),
        iconName: "circle.hexagongrid",
        iconColor: ThemeHexPair(hex: "528BFF"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "528BFF"),
            accentSecondary: ThemeHexPair(hex: "98C379"),
            accentTertiary: ThemeHexPair(hex: "C678DD"),
            backgroundDeep: ThemeHexPair(hex: "282C34"),
            backgroundMedium: ThemeHexPair(hex: "21252B"),
            backgroundLight: ThemeHexPair(hex: "353B45"),
            textPrimary: ThemeHexPair(hex: "ABB2BF"),
            textSecondary: ThemeHexPair(hex: "828997"),
            textTertiary: ThemeHexPair(hex: "5C6370")
        )
    )

    // MARK: - Dracula（ThemeDraculaPlugin, order 132）

    public static let dracula = LumiTheme(
        id: "dracula",
        sortOrder: 1180,
        displayName: LumiThemePackLocalization.string("Dracula", bundle: .module),
        compactName: LumiThemePackLocalization.string("Dracula", bundle: .module),
        description: LumiThemePackLocalization.string("Classic Dracula Official dark palette, high contrast and striking", bundle: .module),
        iconName: "moon.stars.fill",
        iconColor: ThemeHexPair(hex: "BD93F9"),
        appearanceKind: .dark,
        palette: LumiThemePalette(
            accentPrimary: ThemeHexPair(hex: "BD93F9"),
            accentSecondary: ThemeHexPair(hex: "FF79C6"),
            accentTertiary: ThemeHexPair(hex: "8BE9FD"),
            backgroundDeep: ThemeHexPair(hex: "282A36"),
            backgroundMedium: ThemeHexPair(hex: "343746"),
            backgroundLight: ThemeHexPair(hex: "44475A"),
            textPrimary: ThemeHexPair(hex: "F8F8F2"),
            textSecondary: ThemeHexPair(hex: "BFBFBF"),
            textTertiary: ThemeHexPair(hex: "6272A4")
        )
    )
}
