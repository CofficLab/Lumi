import LumiCoreKit
import SwiftUI

public enum TerminalPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "terminal"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.terminal",
        displayName: LumiPluginLocalization.string("Terminal", bundle: .module),
        description: LumiPluginLocalization.string("Native interactive terminal powered by SwiftTerm", bundle: .module),
        order: 90
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                TerminalMainView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "terminal", title: "Terminal", description: "Native interactive terminal powered by SwiftTerm"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Terminal into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Terminal in plugin settings",
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
