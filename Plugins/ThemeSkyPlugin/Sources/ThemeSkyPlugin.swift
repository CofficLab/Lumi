import LumiCoreKit
import LumiUI

public enum ThemeSkyPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.sky",
        displayName: LumiPluginLocalization.string("Sky Theme", bundle: .module),
        description: LumiPluginLocalization.string("Sky inspired app theme that adapts to system appearance", bundle: .module),
        order: 120,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SkyTheme(),
                editorThemeId: "sky-dark"
            )
        ]
    }
}
