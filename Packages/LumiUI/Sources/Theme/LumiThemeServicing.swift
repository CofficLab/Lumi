/// Explicit app-provided API for reading and changing the active LumiUI theme.
@MainActor
public protocol LumiThemeServicing: AnyObject {
    var themeRegistry: LumiUIThemeRegistry { get }
    var themes: [LumiUIThemeContribution] { get }
    var selectedThemeId: String? { get }
    var selectedContribution: LumiUIThemeContribution? { get }

    func selectTheme(id: String) throws
}
