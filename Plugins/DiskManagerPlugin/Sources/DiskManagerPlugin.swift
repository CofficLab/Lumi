import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum DiskManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.disk-manager",
        displayName: LumiPluginLocalization.string("Disk Manager", bundle: .module),
        description: LumiPluginLocalization.string("Inspect local disk capacity and usage.", bundle: .module),
        order: 44,
        category: .system,
        policy: .optIn,
        stage: .beta,
        iconName: "internaldrive",
    )

    @MainActor
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DiskManagerView()
            }
        ]
    }

        @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
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
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "internaldrive",
                            title: LumiPluginLocalization.string("Capacity", bundle: .module),
                            description: LumiPluginLocalization.string("See total and available space per volume", bundle: .module)
                        ),
                        .init(
                            icon: "chart.bar.fill",
                            title: LumiPluginLocalization.string("Usage", bundle: .module),
                            description: LumiPluginLocalization.string("Track how disk space is consumed", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Disk Manager from the sidebar to inspect your volumes.", bundle: .module)
                )
            )
        ]
    }

}
