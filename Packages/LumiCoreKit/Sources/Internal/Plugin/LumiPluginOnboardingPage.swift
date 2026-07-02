import SwiftUI

/// A single onboarding page contributed by a plugin.
///
/// Plugins return instances of this model from `onboardingPages(context:)` to
/// have their custom onboarding views displayed inside the app-wide onboarding
/// flow managed by `OnboardingPlugin`.
@MainActor
public struct LumiPluginOnboardingPage: Identifiable {
    /// Unique identifier, typically prefixed with the plugin ID.
    public let id: String
    /// Display order within the onboarding flow (lower values appear first).
    public let order: Int
    /// Closure that creates the page content view on demand.
    private let contentBuilder: @MainActor () -> AnyView

    /// Creates a new onboarding page.
    /// - Parameters:
    ///   - id: Unique identifier for this page.
    ///   - order: Display order (default `50`).
    ///   - content: A view builder that produces the page content.
    public init(
        id: String,
        order: Int = 50,
        @ViewBuilder content: @escaping @MainActor () -> some View
    ) {
        self.id = id
        self.order = order
        self.contentBuilder = { AnyView(content()) }
    }

    /// Builds the page content view.
    public func makeContent() -> AnyView {
        contentBuilder()
    }
}
