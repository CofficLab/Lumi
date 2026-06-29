import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum HostsManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")
    public static let verbose = true
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "list.bullet.rectangle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.hosts-manager",
        displayName: LumiPluginLocalization.string("Hosts Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage system hosts file configuration", bundle: .module),
        order: 21
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                HostsManagerView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(HostsManagerAboutView())
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [LumiPluginOnboardingPage] {
        [
            LumiPluginOnboardingPage(id: "\(info.id).onboarding", order: info.order) {
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "list.bullet.rectangle",
                            title: LumiPluginLocalization.string("Edit hosts", bundle: .module),
                            description: LumiPluginLocalization.string("Add or remove entries with a live preview", bundle: .module)
                        ),
                        .init(
                            icon: "arrow.uturn.backward",
                            title: LumiPluginLocalization.string("Toggle entries", bundle: .module),
                            description: LumiPluginLocalization.string("Enable or disable mappings without deleting them", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Editing the hosts file requires administrator privileges.", bundle: .module)
                )
            }
        ]
    }
}
