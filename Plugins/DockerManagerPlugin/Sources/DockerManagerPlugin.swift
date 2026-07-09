import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum DockerManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "shippingbox"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.docker-manager",
        displayName: PluginDockerManagerLocalization.string("Docker"),
        description: PluginDockerManagerLocalization.string("Local Docker image management and monitoring"),
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
                DockerImagesView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(DockerManagerAboutView())
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
                            icon: "shippingbox",
                            title: PluginDockerManagerLocalization.string("Images"),
                            description: PluginDockerManagerLocalization.string("Browse and remove local Docker images")
                        ),
                        .init(
                            icon: "chart.bar.fill",
                            title: PluginDockerManagerLocalization.string("Monitoring"),
                            description: PluginDockerManagerLocalization.string("Keep an eye on disk usage and status")
                        ),
                    ],
                    tip: PluginDockerManagerLocalization.string("Make sure Docker is running, then open Docker from the sidebar.")
                )
            )
        ]
    }
}

enum PluginDockerManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
