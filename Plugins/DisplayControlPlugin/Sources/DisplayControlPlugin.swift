import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum DisplayControlPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.display-control",
        displayName: LumiPluginLocalization.string("Display Control", bundle: .module),
        description: LumiPluginLocalization.string(
            "Control brightness, volume, and contrast for external displays via DDC/CI.",
            bundle: .module
        ),
        order: 21,
        category: .system,
        policy: .optIn,
        stage: .beta,
        iconName: "display",
    )

    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.display-control")

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
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
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
            )
        ]
    }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        []
    }
}
