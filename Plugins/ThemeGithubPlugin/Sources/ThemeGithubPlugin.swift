import LumiCoreKit
import LumiUI

public enum ThemeGithubPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.github",
        displayName: String(localized: "GitHub Theme", bundle: .module),
        description: String(localized: "GitHub style app theme", bundle: .module),
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
