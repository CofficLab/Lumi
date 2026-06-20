import LumiCoreKit
import LumiUI

public enum ThemeGithubPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.github",
        displayName: LumiPluginLocalization.string("GitHub Theme", bundle: .module),
        description: LumiPluginLocalization.string("GitHub style app theme", bundle: .module),
        order: 128
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: GitHubTheme(),
                editorThemeId: "github"
            )
        ]
    }
}
