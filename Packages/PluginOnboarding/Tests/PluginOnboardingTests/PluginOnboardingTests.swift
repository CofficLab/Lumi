import Foundation
import KernelCore
import ProviderOnboarding
import ProviderRootView
import ProviderStorage
import Testing
@testable import PluginOnboarding

@MainActor
@Test func onboardingHasStablePluginIdentity() {
    #expect(OnboardingPlugin().id == "com.coffic.lumi.plugin.onboarding")
}

@MainActor
@Test func onboardingRegistersAndRemovesItsPages() throws {
    let kernel = KernelCoreContainer()
    let rootView = DefaultRootViewProvider()
    let dataRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginOnboardingTests-\(UUID().uuidString)")
    let storage = DefaultStorageProvider(dataRootDirectory: dataRoot)
    try kernel.registerProvider((any RootViewProviding).self, rootView)
    try kernel.registerProvider((any StorageProviding).self, storage)

    let plugin = OnboardingPlugin()
    try plugin.onBoot(kernel: kernel)
    let onboarding = try #require(kernel.resolveProvider((any OnboardingProviding).self))
    #expect(onboarding.allPages.map(\.id) == ["onboarding-welcome", "onboarding-ai-setup"])
    #expect(onboarding.isPresented)
    #expect(rootView.overlays.map(\.id) == ["com.coffic.lumi.plugin.onboarding.overlay"])

    try plugin.onShutdown(kernel: kernel)
    #expect(onboarding.allPages.isEmpty)
    #expect(rootView.overlays.isEmpty)
    #expect(kernel.resolveProvider((any OnboardingProviding).self) == nil)
}

@MainActor
@Test func onboardingCompletionMarkerPersistsOnDisk() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginOnboardingStoreTests-\(UUID().uuidString)")
    let firstStore = OnboardingSeenStore(directory: directory)
    #expect(!firstStore.hasSeen)

    firstStore.markSeen()

    let secondStore = OnboardingSeenStore(directory: directory)
    #expect(secondStore.hasSeen)
    secondStore.reset()
    #expect(!secondStore.hasSeen)
}
