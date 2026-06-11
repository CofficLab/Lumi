import LumiCoreKit
import LumiUI

public enum ThemeSummerPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.summer",
        displayName: String(localized: "Summer Theme", bundle: .module),
        description: String(localized: "Summer blue app theme", bundle: .module),
        order: 125
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer"
            )
        ]
    }
}
