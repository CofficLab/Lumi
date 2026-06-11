import LumiCoreKit
import LumiUI

public enum ThemeWinterPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.winter",
        displayName: String(localized: "Winter Theme", bundle: .module),
        description: String(localized: "Winter cool app theme", bundle: .module),
        order: 127
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter"
            )
        ]
    }
}
