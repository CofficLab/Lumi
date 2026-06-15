import LumiCoreKit
import os
import SwiftUI

public enum DiskManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "internaldrive"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.disk-manager",
        displayName: LumiPluginLocalization.string("Disk Manager", bundle: .module),
        description: LumiPluginLocalization.string("Inspect local disk capacity and usage.", bundle: .module),
        order: 44
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DiskManagerView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "internaldrive", title: "Disk Manager", description: "Inspect local disk capacity and usage."),
                .init(icon: "slider.horizontal.3", title: "Management UI", description: "Provides a dedicated management view in Lumi"),
                .init(icon: "gearshape", title: "Configurable", description: "Can be enabled or disabled from plugin settings")
            ],
            steps: [
                "Enable the plugin in plugin settings",
                "Open the plugin view from the sidebar or view container",
                "Manage resources directly inside Lumi"
            ],
            tips: [
                "Review permissions if the plugin accesses system resources",
                "Disable the plugin when you do not need this workflow"
            ]
        )
    }

}
