import Foundation
import KernelCore
import ProviderOnboarding

/// 欢迎页插件 —— 向 Onboarding 贡献首次启动的欢迎页。
///
/// 执行顺序：order = 20
/// - 必须在 `PluginOnboarding`（order=10）之后，确保 `OnboardingProviding`
///   已创建并可用。
@MainActor
public final class PluginWelcome: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.welcome"
    public let order = 20
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.welcome",
        name: "Welcome",
        description: "First-run welcome onboarding page.",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    private static let pageID = "onboarding-welcome"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {}

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let onboarding = kernel.resolveProvider((any OnboardingProviding).self) else { return }

        onboarding.register(
            OnboardingPageItem(id: Self.pageID) {
                WelcomePage()
            }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let onboarding = kernel.resolveProvider((any OnboardingProviding).self) {
            onboarding.unregister(id: Self.pageID)
        }
    }
}
