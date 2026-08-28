import KernelCore
import ProviderOnboarding
import Testing
@testable import PluginOnboarding

@MainActor
@Test func onboardingHasStablePluginIdentity() {
    #expect(OnboardingPlugin().id == "com.coffic.lumi.plugin.onboarding")
}

@MainActor
@Test func onboardingRegistersAndRemovesItsPages() throws {
    let kernel = KernelCoreContainer()
    let onboarding = DefaultOnboardingProviding()
    try kernel.registerProvider((any OnboardingProviding).self, onboarding)

    let plugin = OnboardingPlugin()
    try plugin.onBoot(kernel: kernel)
    #expect(onboarding.allPages.map(\.id) == ["onboarding-welcome", "onboarding-ai-setup"])

    try plugin.onShutdown(kernel: kernel)
    #expect(onboarding.allPages.isEmpty)
}
