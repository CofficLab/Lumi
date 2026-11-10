import ProviderTheme
import SwiftUI

// MARK: - 外观筛选

/// 外观设置页的「按外观筛选」分段控件。
enum ThemeAppearanceFilter: String, CaseIterable, Identifiable {
    case all, dark, light, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: LumiThemePackLocalization.string("All")
        case .dark: LumiThemePackLocalization.string("Dark")
        case .light: LumiThemePackLocalization.string("Light")
        case .system: LumiThemePackLocalization.string("Follow System")
        }
    }

    func matches(_ kind: ProviderTheme.ThemeAppearanceKind) -> Bool {
        switch self {
        case .all: true
        case .dark: kind == .dark
        case .light: kind == .light
        case .system: kind == .system
        }
    }
}

// MARK: - 主题筛选

/// 外观设置页的外观筛选逻辑。
///
/// 从视图抽出，便于在不启动 SwiftUI 的情况下验证筛选语义。
enum ThemeFilter {
    /// 按外观筛选主题。
    ///
    /// - Parameters:
    ///   - themes: 全部主题（保持原有顺序）。
    ///   - filter: 外观筛选。
    /// - Returns: 命中筛选条件的主题，顺序与输入一致。
    static func filter(
        themes: [LumiTheme],
        filter: ThemeAppearanceFilter
    ) -> [LumiTheme] {
        themes.filter { item in
            filter.matches(item.appearanceKind)
        }
    }
}
