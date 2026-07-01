import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum RClickPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")
    public static let verbose = true
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "cursorarrow.click.2"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rclick",
        displayName: LumiPluginLocalization.string("Right Click", bundle: .module),
        description: LumiPluginLocalization.string("Customize Finder right-click menu actions", bundle: .module),
        order: 50
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                RClickSettingsView()
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
                            icon: "cursorarrow.click.2",
                            title: LumiPluginLocalization.string("Custom actions", bundle: .module),
                            description: LumiPluginLocalization.string("Add your own items to Finder's right-click menu", bundle: .module)
                        ),
                        .init(
                            icon: "slider.horizontal.3",
                            title: LumiPluginLocalization.string("Configure", bundle: .module),
                            description: LumiPluginLocalization.string("Choose commands and shortcuts per item", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Right Click from the sidebar to set up actions.", bundle: .module)
                )
            }
        ]
    }

}
