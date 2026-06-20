import LumiCoreKit
import LumiUI

public enum ThemeVscodeDarkPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.vscode-dark",
        displayName: LumiPluginLocalization.string("VS Code 深色 Theme", bundle: .module),
        description: LumiPluginLocalization.string("Visual Studio Code Dark+ IDE theme", bundle: .module),
        order: 129
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark"
            )
        ]
    }
}
