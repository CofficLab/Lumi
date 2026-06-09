import LumiCoreKit
import os
import SwiftUI

public enum AppManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    public static let verbose = false
    nonisolated(unsafe) public static var databaseRootURLProvider: () -> URL = { AppConfig.getDBFolderURL() }

    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "apps.ipad"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-manager",
        displayName: PluginAppManagerLocalization.string("App Manager"),
        description: PluginAppManagerLocalization.string("Browse installed macOS applications."),
        order: 42
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                AppManagerView()
            }
        ]
    }
}
