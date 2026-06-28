import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum InputPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "keyboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.input-manager",
        displayName: LumiPluginLocalization.string("Input Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage input-related behaviors", bundle: .module),
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

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
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
                            icon: "keyboard",
                            title: LumiPluginLocalization.string("Behaviors", bundle: .module),
                            description: LumiPluginLocalization.string("Configure how input is handled across Lumi", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Input Manager from the sidebar to review your settings.", bundle: .module)
                )
            }
        ]
    }

}
