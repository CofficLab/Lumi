import MagicKit
import SwiftUI

/// 首次运行引导插件
actor AgentOnboardingPlugin: SuperPlugin {
    nonisolated static let emoji = "🎉"
    nonisolated static let verbose: Bool = false
    static let id = "AgentOnboarding"
    static let displayName = String(localized: "Onboarding", table: "AgentOnboarding")
    static let description = String(localized: "Show first-run onboarding and guidance entry points", table: "AgentOnboarding")
    static let iconName = "hand.wave"
    static var order: Int { 10 }
    static let enable: Bool = true

    static let shared = AgentOnboardingPlugin()

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(OnboardingRootOverlay(content: content()))
    }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
