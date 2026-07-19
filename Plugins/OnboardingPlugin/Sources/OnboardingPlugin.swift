import LumiCoreKit
import SwiftUI

/// First-run onboarding plugin.
public enum OnboardingPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.onboarding",
        displayName: LumiPluginLocalization.string("Onboarding", bundle: .module),
        description: LumiPluginLocalization.string("Show first-run onboarding and guidance entry points", bundle: .module),
        order: 10,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "hand.wave",
    )

    @MainActor
    public static func rootOverlays(context: any LumiCoreAccessing) -> [LumiRootOverlayItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                OnboardingRootOverlay(content: content)
            }
        ]
    }

    @MainActor
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                OnboardingWelcomePage()
            )
        ]
    }
}
