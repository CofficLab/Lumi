import LumiCoreKit
import SwiftUI

public enum FontConfigPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .theme
    public static let iconName = "textformat"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.font-config",
        displayName: LumiPluginLocalization.string("Font Config", bundle: .module),
        description: LumiPluginLocalization.string("Quick font switching in status bar", bundle: .module),
        order: 78
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    FontStatusBarView()
                }
            )
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "textformat", title: "Font Config", description: "Quick font switching in status bar"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Font Config into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Font Config in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}
