import LumiCoreKit
import os
import SwiftUI

public enum QuickLauncherPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .system
    public static let iconName = "app.grid"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.quick-launcher",
        displayName: LumiPluginLocalization.string("Quick Launcher", bundle: .module),
        description: LumiPluginLocalization.string("Quick access to system apps and utilities", bundle: .module),
        order: 8
    )

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).launcher", order: info.order) {
                QuickLauncherMenuBarPopupView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "app.grid", title: "Quick Launcher", description: "Quick access to system apps and utilities"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Quick Launcher into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Quick Launcher in plugin settings",
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
