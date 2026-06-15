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
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
        )
    }

}
