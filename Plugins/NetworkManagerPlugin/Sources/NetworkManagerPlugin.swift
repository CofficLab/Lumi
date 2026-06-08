import Foundation
import LumiCoreKit
import SuperLogKit
import os

public enum NetworkManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    public nonisolated static let emoji = "🛜"
    public nonisolated static let verbose: Bool = false

    public static let iconName = "network"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.network-manager",
        displayName: String(localized: "Network Monitor", bundle: .module),
        description: String(localized: "Real-time monitoring of network speed, traffic, and connection status", bundle: .module),
        order: 30
    )
    public static let category: LumiPluginCategory = .system
    public static let policy: LumiPluginPolicy = .optIn

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                NetworkDashboardView()
            }
        ]
    }

    @MainActor
    public static func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        [
            LumiMenuBarContentItem(id: "\(info.id).speed", order: info.order) {
                NetworkMenuBarContentView()
            }
        ]
    }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).network", order: info.order) {
                NetworkMenuBarPopupView()
            }
        ]
    }
}
