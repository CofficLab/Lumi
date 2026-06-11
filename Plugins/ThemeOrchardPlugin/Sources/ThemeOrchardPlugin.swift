import LumiCoreKit
import LumiUI

public enum ThemeOrchardPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.orchard",
        displayName: String(localized: "Orchard Theme", bundle: .module),
        description: String(localized: "Orchard red app theme", bundle: .module),
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
