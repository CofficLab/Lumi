import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum MenuBarManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    public static let verbose = true
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "menubar.rectangle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.menubar-manager",
        displayName: LumiPluginLocalization.string("Menu Bar Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage your menu bar items", bundle: .module),
        order: 20
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                MenuBarSettingsView()
            }
        ]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .manager
        )
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
                            icon: "menubar.rectangle",
                            title: LumiPluginLocalization.string("Menu bar items", bundle: .module),
                            description: LumiPluginLocalization.string("See and organize items contributed by plugins", bundle: .module)
                        ),
                        .init(
                            icon: "slider.horizontal.3",
                            title: LumiPluginLocalization.string("Reorder", bundle: .module),
                            description: LumiPluginLocalization.string("Arrange menu bar items to your liking", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Menu Bar Manager from the sidebar to manage items.", bundle: .module)
                )
            }
        ]
    }

}
