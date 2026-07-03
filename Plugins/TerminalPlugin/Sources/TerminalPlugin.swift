import LumiCoreKit
import LumiUI
import SwiftUI

public enum TerminalPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "terminal"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.terminal",
        displayName: LumiPluginLocalization.string("Terminal", bundle: .module),
        description: LumiPluginLocalization.string("Native interactive terminal powered by SwiftTerm", bundle: .module),
        order: 90
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                TerminalMainView()
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
                            icon: "rectangle.3.group",
                            title: LumiPluginLocalization.string("Multiple sessions", bundle: .module),
                            description: LumiPluginLocalization.string("Open several shells side by side", bundle: .module)
                        ),
                        .init(
                            icon: "keyboard",
                            title: LumiPluginLocalization.string("Full keyboard", bundle: .module),
                            description: LumiPluginLocalization.string("Complete VT escapes and shell integration", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Terminal from the sidebar at any time.", bundle: .module)
                )
            )
        ]
    }

}
