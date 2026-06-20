import LumiCoreKit
import os
import SwiftUI

public enum BrewManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
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
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .manager
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
