import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI
import SuperLogKit
import os

public enum NetworkManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    public nonisolated static let emoji = "🛜"
    public nonisolated static let verbose: Bool = true


    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.network-manager",
        displayName: LumiPluginLocalization.string("Network Monitor", bundle: .module),
        description: LumiPluginLocalization.string("Real-time monitoring of network speed, traffic, and connection status", bundle: .module),
        order: 30,
        category: .system,
        policy: .optIn,
        stage: .beta,
        iconName: "network",
    )

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
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "gauge.with.dots.needle.bottom.50percent",
                            title: LumiPluginLocalization.string("Live speed", bundle: .module),
                            description: LumiPluginLocalization.string("Real-time upload and download rates", bundle: .module)
                        ),
                        .init(
                            icon: "menubar.rectangle",
                            title: LumiPluginLocalization.string("Menu bar", bundle: .module),
                            description: LumiPluginLocalization.string("Keep an eye on traffic from the menu bar", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Network Monitor from the sidebar or the menu bar.", bundle: .module)
                )
            )
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
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(NetworkManagerAboutView())
    }
}
