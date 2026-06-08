import LumiCoreKit
import LumiUI

public enum ThemeStatusBarPlugin: LumiPlugin {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme-status-bar",
        displayName: "Theme Status Bar",
        description: "Adds a status bar theme switcher.",
        order: 76
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard let themeService = context.resolve(LumiThemeServicing.self) else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).switcher",
                title: "Theme",
                systemImage: "paintbrush",
                placement: .trailing,
                statusBarView: {
                    ThemeStatusBarView(themeService: themeService)
                }
            )
        ]
    }
}
