import LumiCoreKit
import os
import SwiftUI

public enum HostsManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .system
    public static let iconName = "list.bullet.rectangle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.hosts-manager",
        displayName: String(localized: "Hosts Manager", bundle: .module),
        description: String(localized: "Manage system hosts file configuration", bundle: .module),
        order: 21
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                HostsManagerView()
            }
        ]
    }
}
