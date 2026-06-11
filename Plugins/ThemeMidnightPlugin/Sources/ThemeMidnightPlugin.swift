import LumiCoreKit
import LumiUI

public enum ThemeMidnightPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.midnight",
        displayName: String(localized: "Midnight Theme", bundle: .module),
        description: String(localized: "Deep dark blue color scheme", bundle: .module),
        order: 120
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight"
            )
        ]
    }
}
