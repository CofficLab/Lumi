import MagicKit
import SwiftUI

/// 首次运行引导插件
actor AgentOnboardingPlugin: SuperPlugin {
    nonisolated static let emoji = "🎉"
    nonisolated static let verbose = false

    static let id = "AgentOnboarding"
    static let displayName = String(localized: "Onboarding", table: "AgentOnboardingPlugin")
    static let description = String(localized: "Show first-run onboarding and guidance entry points", table: "AgentOnboardingPlugin")
    static let iconName = "hand.wave"
    static var order: Int { 10 }
    static let enable: Bool = true

    static let shared = AgentOnboardingPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(OnboardingRootOverlay(content: content()))
    }
}
