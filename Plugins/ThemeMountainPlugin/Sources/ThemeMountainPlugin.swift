import LumiCoreKit
import LumiUI
import os

public enum ThemeMountainPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.mountain")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.mountain",
        displayName: LumiPluginLocalization.string("Mountain Theme", bundle: .module),
        description: LumiPluginLocalization.string("Mountain gray app theme", bundle: .module),
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
