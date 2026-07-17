import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum RClickPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")
    public static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rclick",
        displayName: LumiPluginLocalization.string("Right Click", bundle: .module),
        description: LumiPluginLocalization.string("Customize Finder right-click menu actions", bundle: .module),
        order: 50,
        category: .general,
        policy: .disabled,
        stage: .beta,
        iconName: "cursorarrow.click.2",
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
                RClickSettingsView()
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
            )
        ]
    }

}
