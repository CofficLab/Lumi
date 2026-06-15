import LumiCoreKit
import os
import SwiftUI

public enum InputPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "keyboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.input-manager",
        displayName: LumiPluginLocalization.string("Input Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage input-related behaviors", bundle: .module),
        order: 70
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                InputSettingsView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "keyboard", title: "Input Manager", description: "Manage input-related behaviors"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Input Manager into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Input Manager in plugin settings",
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
