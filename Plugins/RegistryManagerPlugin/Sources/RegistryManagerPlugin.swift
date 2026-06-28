import LumiCoreKit
import LumiUI
import SwiftUI

public enum RegistryManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "arrow.triangle.2.circlepath"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.registry-manager",
        displayName: LumiPluginLocalization.string("Registry Manager", bundle: .module),
        description: LumiPluginLocalization.string("Manage Lumi registries", bundle: .module),
        order: 80
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                RegistryManagerView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(RegistryManagerAboutView())
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
                            icon: "externaldrive.connected.to.line.below",
                            title: LumiPluginLocalization.string("Connect", bundle: .module),
                            description: LumiPluginLocalization.string("Add and manage Lumi registries", bundle: .module)
                        ),
                        .init(
                            icon: "arrow.triangle.2.circlepath",
                            title: LumiPluginLocalization.string("Sync", bundle: .module),
                            description: LumiPluginLocalization.string("Refresh registry contents on demand", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Registry Manager from the sidebar to manage sources.", bundle: .module)
                )
            }
        ]
    }
}
