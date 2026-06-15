import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI
import SuperLogKit
import os

public enum NetworkManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    public nonisolated static let emoji = "🛜"
    public nonisolated static let verbose: Bool = false

    public static let iconName = "network"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.network-manager",
        displayName: LumiPluginLocalization.string("Network Monitor", bundle: .module),
        description: LumiPluginLocalization.string("Real-time monitoring of network speed, traffic, and connection status", bundle: .module),
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

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "network", title: "Network Monitor", description: "Real-time monitoring of network speed, traffic, and connection status"),
                .init(icon: "slider.horizontal.3", title: "Management UI", description: "Provides a dedicated management view in Lumi"),
                .init(icon: "menubar.rectangle", title: "Menu Bar Widget", description: "Shows live network activity in the menu bar"),
            ],
            steps: [
                "Enable Network Monitor in plugin settings",
                "Open the network dashboard from the sidebar",
                "Use the menu bar widget for quick status checks",
            ],
            tips: [
                "Keep the plugin enabled when you need live traffic visibility",
                "Use the dashboard for detailed connection information",
            ]
        )
    }
}
