import LumiCoreKit
import LumiUI

public enum ThemeMountainPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.mountain",
        displayName: String(localized: "Mountain Theme", bundle: .module),
        description: String(localized: "Mountain gray app theme", bundle: .module),
        order: 129
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain"
            )
        ]
    }
}
