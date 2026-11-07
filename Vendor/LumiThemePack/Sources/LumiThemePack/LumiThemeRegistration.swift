import ProviderTheme

/// Canonical theme-count and identity contract shared by every host app.
public enum LumiThemeContract {
    /// The three built-in appearance choices that are not part of the shared
    /// catalog. The shared `lumi` theme replaces the built-in `lumi` entry.
    public static let additionalBuiltinThemeIDs: [String] = [
        "lumi-system",
        "lumi-dark",
        "lumi-light",
    ]

    public static let catalogThemeCount = 19
    public static let selectableThemeCount = catalogThemeCount + additionalBuiltinThemeIDs.count

    /// The complete selectable ID set after the catalog is registered over
    /// `ProviderTheme.BuiltinThemes.all`.
    public static var selectableThemeIDs: [String] {
        LumiThemeCatalog.all.map(\.id) + additionalBuiltinThemeIDs
    }
}

/// Registers or removes the shared theme catalog through the host's theme provider.
///
/// 宿主可传入 `themeIDs` 白名单只加载部分主题（`nil` 表示全量加载），
/// 使不同 App 能按自身定位裁剪主题库，同时保持「外观」设置页、
/// 主题菜单等消费方继续从 `ThemeProviding.themes` 读取实际生效的主题。
@MainActor
public enum LumiThemeRegistration {
    /// 按白名单筛选目录主题。
    ///
    /// - Parameter themeIDs: 主题 id 白名单；`nil` 表示全量目录。
    ///   未知 id 会被忽略，不影响其余主题生效。
    /// - Returns: 命中的主题，保持目录原始顺序。
    public nonisolated static func themes(for themeIDs: [String]?) -> [LumiTheme] {
        guard let themeIDs else { return LumiThemeCatalog.all }
        let allowed = Set(themeIDs)
        return LumiThemeCatalog.all.filter { allowed.contains($0.id) }
    }

    /// 白名单中不存在于目录的主题 id。
    ///
    /// 供宿主在启动时校验配置，避免拼写错误导致主题静默缺失。
    ///
    /// - Parameter themeIDs: 主题 id 白名单；`nil` 表示全量目录，无未知 id。
    /// - Returns: 未命中目录的 id，按白名单去重后的顺序返回。
    public nonisolated static func unknownIDs(in themeIDs: [String]?) -> [String] {
        guard let themeIDs else { return [] }
        let known = Set(LumiThemeCatalog.all.map(\.id))
        var seen = Set<String>()
        return themeIDs.filter { !known.contains($0) && seen.insert($0).inserted }
    }

    /// 注册目录主题到宿主的 ThemeProvider。
    ///
    /// - Parameters:
    ///   - provider: 宿主的主题 Provider。
    ///   - themeIDs: 主题 id 白名单；`nil` 表示全量目录（默认，向后兼容）。
    public static func register(in provider: any ThemeProviding, themeIDs: [String]? = nil) {
        themes(for: themeIDs).forEach(provider.registerTheme)
    }

    /// 从宿主的 ThemeProvider 注销目录主题。
    ///
    /// - Parameters:
    ///   - provider: 宿主的主题 Provider。
    ///   - themeIDs: 主题 id 白名单；`nil` 表示全量目录（默认，向后兼容）。
    ///   与 ``register(in:themeIDs:)`` 传入相同白名单可实现对称撤回。
    public static func unregister(from provider: any ThemeProviding, themeIDs: [String]? = nil) {
        themes(for: themeIDs).forEach { provider.unregisterTheme(id: $0.id) }
    }
}
