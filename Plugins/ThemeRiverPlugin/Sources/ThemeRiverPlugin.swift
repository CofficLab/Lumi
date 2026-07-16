import LumiCoreKit
import LumiUI

public enum ThemeRiverPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.river",
        displayName: LumiPluginLocalization.string("River Theme", bundle: .module),
        description: LumiPluginLocalization.string("River cyan app theme", bundle: .module),
        order: 130,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
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
