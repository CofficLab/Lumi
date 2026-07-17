import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum MenuBarManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    public static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.menubar-manager",
        displayName: LumiPluginLocalization.string("Menu Bar Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage your menu bar items", bundle: .module),
        order: 20,
        category: .general,
        policy: .disabled,
        stage: .beta,
        iconName: "menubar.rectangle",
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [
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
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
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
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
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
            )
        ]
    }

}
