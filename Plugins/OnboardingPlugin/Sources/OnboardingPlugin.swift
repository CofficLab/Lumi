import SwiftUI
import LumiCoreKit

/// 首次运行引导插件
public actor OnboardingPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let emoji = "🎉"
    public nonisolated static let verbose: Bool = true
    public static let id = "Onboarding"
    public static let displayName = String(localized: "Onboarding", table: "OnboardingPlugin")
    public static let description = String(localized: "Show first-run onboarding and guidance entry points", table: "OnboardingPlugin")
    public static let iconName = "hand.wave"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 10 }

    public static let shared = OnboardingPlugin()

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(OnboardingRootOverlay(content: content()))
    }

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}
}
