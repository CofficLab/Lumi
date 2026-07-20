/// Explicit app-provided API for reading and changing the active LumiUI theme.
@MainActor
public protocol LumiThemeServicing: AnyObject {
    var themeRegistry: LumiUIThemeRegistry { get }
    var themes: [LumiUIThemeContribution] { get }
    var selectedThemeId: String? { get }
    var selectedContribution: LumiUIThemeContribution? { get }

    func selectTheme(id: String) throws

    /// 注册一个主题贡献
    func registerTheme(_ contribution: LumiUIThemeContribution)

    /// 注销一个主题贡献
    func unregisterTheme(id: String)
}
