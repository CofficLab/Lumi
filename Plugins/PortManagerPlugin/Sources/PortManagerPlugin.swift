import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum PortManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    public static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.port-manager",
        displayName: LumiPluginLocalization.string("Port Manager", bundle: .module),
        description: LumiPluginLocalization.string("Inspect local listening ports.", bundle: .module),
        order: 43,
        category: .system,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.up.arrow.down.circle",
    )

    @MainActor
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                PortManagerView()
            }
        ]
    }

    @MainActor
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "dot.radiowaves.left.and.right",
                            title: LumiPluginLocalization.string("Listening ports", bundle: .module),
                            description: LumiPluginLocalization.string("See every process bound to a local port", bundle: .module)
                        ),
                        .init(
                            icon: "magnifyingglass",
                            title: LumiPluginLocalization.string("Search", bundle: .module),
                            description: LumiPluginLocalization.string("Filter by port or process name", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Port Manager from the sidebar to audit open ports.", bundle: .module)
                )
            )
        ]
    }
}
