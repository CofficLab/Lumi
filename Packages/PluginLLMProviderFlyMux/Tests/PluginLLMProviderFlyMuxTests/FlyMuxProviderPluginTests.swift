import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderFlyMux

@MainActor
struct FlyMuxProviderPluginTests {

    @Test("onBoot 把 FlyMux 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = FlyMuxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "flymux")?.providerInfo.id == "flymux")
    }
}
