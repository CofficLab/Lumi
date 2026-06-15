import LumiCoreKit
import os
import SwiftUI

public enum BrewManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "mug.fill"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.brew-manager",
        displayName: PluginBrewManagerLocalization.string("Package Management"),
        description: PluginBrewManagerLocalization.string("Manage Homebrew packages and casks"),
        order: 60
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                BrewManagerView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "mug.fill", title: "Package Management", description: "Manage Homebrew packages and casks"),
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

enum PluginBrewManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
