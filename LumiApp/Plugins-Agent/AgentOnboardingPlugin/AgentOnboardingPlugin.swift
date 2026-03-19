import MagicKit
import SwiftUI

actor AgentOnboardingPlugin: SuperPlugin {
    static let id = "AgentOnboarding"
    static let displayName = "Onboarding"
    static let description = "Show first-run onboarding and guidance entry points"
    static let iconName = "graduationcap"
    static var order: Int { 20 }
    static let enable: Bool = true
    static var isConfigurable: Bool { true }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(OnboardingRootOverlay(content: content()))
    }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
