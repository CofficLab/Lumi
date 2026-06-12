import LumiCoreKit
import os
import SwiftUI

public enum PortManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "arrow.up.arrow.down.circle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.port-manager",
        displayName: LumiPluginLocalization.string("Port Manager", bundle: .module),
        description: LumiPluginLocalization.string("Inspect local listening ports.", bundle: .module),
        order: 43
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                PortManagerView()
            }
        ]
    }
}
