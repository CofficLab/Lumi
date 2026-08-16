import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderHyperAPI

@MainActor
struct HyperAPIProviderPluginTests {

    @Test("onBoot 把 HyperAPI 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = HyperAPIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "hyperapi")?.providerInfo.id == "hyperapi")
    }
}
