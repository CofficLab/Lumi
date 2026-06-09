import LumiCoreKit
import os
import SwiftUI

public enum InputPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "keyboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.input-manager",
        displayName: String(localized: "Input Manager", bundle: .module),
        description: String(localized: "Manage input-related behaviors", bundle: .module),
        order: 70
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                InputSettingsView()
            }
        ]
    }
}
