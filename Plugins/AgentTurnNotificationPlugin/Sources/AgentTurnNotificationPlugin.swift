import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// Sends a system notification when an agent turn completes.
public enum AgentTurnNotificationPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
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
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

}
