import LumiCoreKit
import os
import SwiftUI

public enum ClipboardManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "doc.on.clipboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.clipboard-manager",
        displayName: String(localized: "Clipboard", bundle: .module),
        description: String(localized: "Manage clipboard history and snippets", bundle: .module),
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
                ClipboardHistoryView()
            }
        ]
    }
}
