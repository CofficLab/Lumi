import SwiftUI

/// Environment key that carries aggregated onboarding pages from all enabled plugins.
///
/// `RootView` sets this value before applying root overlays. `OnboardingRootOverlay`
/// reads the value to display the combined onboarding flow.
public struct OnboardingPagesEnvironmentKey: EnvironmentKey {
    public static let defaultValue: [LumiPluginOnboardingPage] = []
}

extension EnvironmentValues {
    /// The aggregated onboarding pages from all enabled plugins.
    public var onboardingPages: [LumiPluginOnboardingPage] {
        get { self[OnboardingPagesEnvironmentKey.self] }
        set { self[OnboardingPagesEnvironmentKey.self] = newValue }
    }
}
