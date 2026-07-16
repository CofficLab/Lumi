import LumiCoreKit
import LumiUI

public enum ThemeAuroraPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.aurora",
        displayName: LumiPluginLocalization.string("Aurora Theme", bundle: .module),
        description: LumiPluginLocalization.string("Aurora purple app theme", bundle: .module),
        order: 121,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora"
            )
        ]
    }
}
