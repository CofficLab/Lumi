import LumiCoreKit
import os
import SwiftUI

/// Sends a system notification when an agent turn completes.
public enum AgentTurnNotificationPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "bell.badge"

    public static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.turn-notification"
    )

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.turn-notification",
        displayName: LumiPluginLocalization.string("Turn Notification", bundle: .module),
        description: LumiPluginLocalization.string("Send a system notification when an Agent turn finishes.", bundle: .module),
        order: 99
    )

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                AgentTurnNotificationOverlay(content: content)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "bell.badge", title: "Turn Notification", description: "Send a system notification when an Agent turn finishes."),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Turn Notification into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Turn Notification in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}
