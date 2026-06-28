import LumiCoreKit
import LumiUI
import SwiftUI

public enum NettoPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "shield.lefthalf.filled"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.netto",
        displayName: LumiPluginLocalization.string("Netto Firewall", bundle: .module),
        description: LumiPluginLocalization.string("Manage network permissions for macOS applications.", bundle: .module),
        order: 99
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                NettoDashboardView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(NettoAboutView())
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
                            icon: "shield.lefthalf.filled",
                            title: LumiPluginLocalization.string("Per-app rules", bundle: .module),
                            description: LumiPluginLocalization.string("Allow or block network access for each app", bundle: .module)
                        ),
                        .init(
                            icon: "eye",
                            title: LumiPluginLocalization.string("Visibility", bundle: .module),
                            description: LumiPluginLocalization.string("See which apps are reaching the network", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Netto Firewall from the sidebar to review permissions.", bundle: .module)
                )
            }
        ]
    }
}
