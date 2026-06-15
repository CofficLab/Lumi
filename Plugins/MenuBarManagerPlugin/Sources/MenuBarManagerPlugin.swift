import LumiCoreKit
import os
import SwiftUI

public enum MenuBarManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "menubar.rectangle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.menubar-manager",
        displayName: LumiPluginLocalization.string("Menu Bar Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage your menu bar items", bundle: .module),
        order: 20
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                MenuBarSettingsView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "menubar.rectangle", title: "Menu Bar Manager", description: "Manage your menu bar items"),
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
