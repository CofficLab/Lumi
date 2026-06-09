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
        displayName: String(localized: "Disk Manager", bundle: .module),
        description: String(localized: "Inspect local disk capacity and usage.", bundle: .module),
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
}
