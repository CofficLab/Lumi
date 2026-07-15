import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum AppManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    public static let verbose = false
    nonisolated(unsafe) public static var databaseRootURLProvider: () -> URL = {
        currentLumiCoreDataRootDirectory ?? lumiCoreFallbackDataRootDirectory
    }

    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "apps.ipad"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-manager",
        displayName: PluginAppManagerLocalization.string("App Manager"),
        description: PluginAppManagerLocalization.string("Browse installed macOS applications."),
        order: 42
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                AppManagerView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(AppManagerAboutView())
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
                            icon: "square.grid.2x2",
                            title: PluginAppManagerLocalization.string("Browse apps"),
                            description: PluginAppManagerLocalization.string("See all installed macOS applications")
                        ),
                        .init(
                            icon: "magnifyingglass",
                            title: PluginAppManagerLocalization.string("Search"),
                            description: PluginAppManagerLocalization.string("Find apps by name instantly")
                        ),
                    ],
                    tip: PluginAppManagerLocalization.string("Open App Manager from the sidebar to explore your apps.")
                )
            )
        ]
    }
}
