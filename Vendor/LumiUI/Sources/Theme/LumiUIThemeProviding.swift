/// Optional plugin capability for contributing LumiUI themes.
public protocol LumiUIThemeProviding {
    @MainActor
    static func themeContributions() -> [LumiUIThemeContribution]
}
