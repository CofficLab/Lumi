import LumiCoreKit
import LumiUI
import SwiftUI

public enum DisplayControlPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.display-control",
        displayName: LumiPluginLocalization.string("Display Control", bundle: .module),
        description: LumiPluginLocalization.string(
            "Control brightness, volume, and contrast for external displays via DDC/CI.",
            bundle: .module
        ),
        order: 21
    )
    public static let category: LumiPluginCategory = .system
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta

    public static let iconName = "display"

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: LumiPluginLocalization.string("Display Control", bundle: .module),
                systemImage: iconName
            ) {
                DisplayControlView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(DisplayControlAboutView())
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
                            icon: "sun.max",
                            title: LumiPluginLocalization.string("Brightness & contrast", bundle: .module),
                            description: LumiPluginLocalization.string("Adjust external displays via DDC/CI", bundle: .module)
                        ),
                        .init(
                            icon: "speaker.wave.2",
                            title: LumiPluginLocalization.string("Volume", bundle: .module),
                            description: LumiPluginLocalization.string("Control built-in speakers", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Display Control from the sidebar to tune your screens.", bundle: .module)
                )
            }
        ]
    }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        []
    }
}
