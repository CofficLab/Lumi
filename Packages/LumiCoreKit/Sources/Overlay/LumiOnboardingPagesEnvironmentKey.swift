import SwiftUI

/// Type-erased view wrapper that is Sendable-safe for use in collections
public struct OnboardingPageView: @unchecked Sendable {
    public let order: Int
    public let view: AnyView

    public init(order: Int, view: AnyView) {
        self.order = order
        self.view = view
    }
}

/// Environment key that carries aggregated onboarding pages from all enabled plugins.
///
/// `RootView` sets this value before applying root overlays. `OnboardingRootOverlay`
/// reads the value to display the combined onboarding flow.
public struct OnboardingPagesEnvironmentKey: EnvironmentKey {
    public static let defaultValue: [OnboardingPageView] = []
}

extension EnvironmentValues {
    /// The aggregated onboarding pages from all enabled plugins.
    public var onboardingPages: [OnboardingPageView] {
        get { self[OnboardingPagesEnvironmentKey.self] }
        set { self[OnboardingPagesEnvironmentKey.self] = newValue }
    }
}
