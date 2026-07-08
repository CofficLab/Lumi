import LumiCoreKit
import SwiftUI

/// First-run onboarding plugin.
public enum OnboardingPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "hand.wave"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.onboarding",
        displayName: LumiPluginLocalization.string("Onboarding", bundle: .module),
        description: LumiPluginLocalization.string("Show first-run onboarding and guidance entry points", bundle: .module),
        order: 10
    )

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                OnboardingRootOverlay(content: content)
            }
        ]
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                OnboardingWelcomePage()
            )
        ]
    }
}
