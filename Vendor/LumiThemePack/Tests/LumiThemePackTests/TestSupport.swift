import Foundation
import ProviderTheme

@testable import LumiThemePack

// MARK: - 主题夹具

/// 构造用于测试的最小主题。
///
/// 色板使用**亮暗双档**色值（`ThemeHexPair(light:dark:)`），
/// 以便验证外观切换会改变解析结果。
@MainActor
enum ThemeFixture {
    static func theme(
        id: String,
        displayName: String? = nil,
        compactName: String? = nil,
        description: String = "",
        appearanceKind: ThemeAppearanceKind = .dark,
        sortOrder: Int = 100,
        singleHex: Bool = false
    ) -> LumiTheme {
        func pair(_ light: String, _ dark: String) -> ThemeHexPair {
            singleHex ? ThemeHexPair(hex: light) : ThemeHexPair(light: light, dark: dark)
        }

        return LumiTheme(
            id: id,
            sortOrder: sortOrder,
            displayName: displayName ?? id,
            compactName: compactName,
            description: description,
            iconName: "circle",
            iconColor: pair("111111", "EEEEEE"),
            appearanceKind: appearanceKind,
            palette: LumiThemePalette(
                accentPrimary: pair("111111", "EEEEEE"),
                accentSecondary: pair("222222", "DDDDDD"),
                accentTertiary: pair("333333", "CCCCCC"),
                backgroundDeep: pair("444444", "BBBBBB"),
                backgroundMedium: pair("555555", "AAAAAA"),
                backgroundLight: pair("666666", "999999"),
                textPrimary: pair("777777", "888888"),
                textSecondary: pair("888888", "777777"),
                textTertiary: pair("999999", "666666")
            )
        )
    }
}
