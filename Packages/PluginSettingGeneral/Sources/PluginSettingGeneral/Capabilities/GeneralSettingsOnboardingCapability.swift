import ProviderOnboarding

/// 通用设置页需要的最小新手引导能力。
@MainActor
protocol OnboardingCapability: AnyObject {
    var isOnboardingAvailable: Bool { get }
    func replayOnboarding()
}

/// 默认实现：把 `OnboardingProviding` 收窄为本插件的新手引导能力。
@MainActor
final class OnboardingCapabilityAdapter: OnboardingCapability {
    private let onboardingProvider: (any OnboardingProviding)?

    init(onboardingProvider: (any OnboardingProviding)?) {
        self.onboardingProvider = onboardingProvider
    }

    var isOnboardingAvailable: Bool {
        onboardingProvider != nil
    }

    func replayOnboarding() {
        onboardingProvider?.replay()
    }
}