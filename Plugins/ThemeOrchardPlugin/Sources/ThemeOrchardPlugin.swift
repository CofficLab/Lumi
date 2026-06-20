import LumiCoreKit
import LumiUI

public enum ThemeOrchardPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.orchard",
        displayName: LumiPluginLocalization.string("Orchard Theme", bundle: .module),
        description: LumiPluginLocalization.string("Orchard red app theme", bundle: .module),
        order: 128
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OrchardTheme(),
                editorThemeId: "orchard"
            )
        ]
    }
}
