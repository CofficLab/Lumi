import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum ClipboardManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")
    public static let verbose = true
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "doc.on.clipboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.clipboard-manager",
        displayName: LumiPluginLocalization.string("Clipboard", bundle: .module),
        description: LumiPluginLocalization.string("Manage clipboard history and snippets", bundle: .module),
        order: 70
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                ClipboardHistoryView()
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(ClipboardManagerAboutView())
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
                            icon: "clock.arrow.circlepath",
                            title: LumiPluginLocalization.string("History", bundle: .module),
                            description: LumiPluginLocalization.string("Browse and re-copy anything you've copied", bundle: .module)
                        ),
                        .init(
                            icon: "text.append",
                            title: LumiPluginLocalization.string("Snippets", bundle: .module),
                            description: LumiPluginLocalization.string("Save reusable text for quick access", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Clipboard from the sidebar to revisit your history.", bundle: .module)
                )
            }
        ]
    }
}
