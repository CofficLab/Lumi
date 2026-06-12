import LumiCoreKit
import LumiUI

public enum ThemeRiverPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.river",
        displayName: LumiPluginLocalization.string("River Theme", bundle: .module),
        description: LumiPluginLocalization.string("River cyan app theme", bundle: .module),
        order: 130
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: RiverTheme(),
                editorThemeId: "river"
            )
        ]
    }
}
