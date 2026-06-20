import LumiCoreKit
import os
import SwiftUI

public enum MenuBarManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
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
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .manager
        )
    }

}
