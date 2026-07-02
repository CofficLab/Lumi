import LumiCoreKit
import LumiUI
import os

public enum ThemeVoidPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.void")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.void",
        displayName: LumiPluginLocalization.string("虚空深黑 Theme", bundle: .module),
        description: LumiPluginLocalization.string("纯粹的虚空黑，深邃而神秘", bundle: .module),
        order: 123
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void"
            )
        ]
    }
}
