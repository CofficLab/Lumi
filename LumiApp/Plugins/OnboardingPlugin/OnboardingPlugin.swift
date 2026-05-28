import SwiftUI

/// 首次运行引导插件
actor OnboardingPlugin: SuperPlugin {
    nonisolated static let emoji = "🎉"
    nonisolated static let verbose: Bool = true
    static let id = "Onboarding"
    static let displayName = String(localized: "Onboarding", table: "OnboardingPlugin")
    static let description = String(localized: "Show first-run onboarding and guidance entry points", table: "OnboardingPlugin")
    static let iconName = "hand.wave"
    static var category: PluginCategory { .agent }
    static var order: Int { 10 }

    static let shared = OnboardingPlugin()

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(OnboardingRootOverlay(content: content()))
    }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
