import LumiCoreKit
import os
import SwiftUI

public enum RClickPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "cursorarrow.click.2"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rclick",
        displayName: LumiPluginLocalization.string("Right Click", bundle: .module),
        description: LumiPluginLocalization.string("Customize Finder right-click menu actions", bundle: .module),
        order: 50
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                RClickSettingsView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "cursorarrow.click.2", title: "Right Click", description: "Customize Finder right-click menu actions"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Right Click into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Right Click in plugin settings",
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
