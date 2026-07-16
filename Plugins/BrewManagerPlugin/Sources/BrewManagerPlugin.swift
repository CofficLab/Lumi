import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum BrewManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")
    public static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.brew-manager",
        displayName: PluginBrewManagerLocalization.string("Package Management"),
        description: PluginBrewManagerLocalization.string("Manage Homebrew packages and casks"),
        order: 60,
        category: .development,
        policy: .optOut,
        stage: .beta,
        iconName: "mug.fill",
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                BrewManagerView()
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
                            title: PluginBrewManagerLocalization.string("Packages & casks"),
                            description: PluginBrewManagerLocalization.string("Install, upgrade, and remove Homebrew formulae")
                        ),
                        .init(
                            icon: "arrow.clockwise",
                            title: PluginBrewManagerLocalization.string("Stay up to date"),
                            description: PluginBrewManagerLocalization.string("Refresh and upgrade everything in one place")
                        ),
                    ],
                    tip: PluginBrewManagerLocalization.string("Open Package Management from the sidebar to manage brew.")
                )
            )
        ]
    }

}

enum PluginBrewManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
