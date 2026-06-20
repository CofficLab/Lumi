import LumiCoreKit
import LumiUI

public enum ThemeNebulaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.nebula",
        displayName: LumiPluginLocalization.string("星云粉 Theme", bundle: .module),
        description: LumiPluginLocalization.string("浪漫的星云粉，柔和而温暖", bundle: .module),
        order: 122
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula"
            )
        ]
    }
}
