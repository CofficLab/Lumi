import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderAiRouter

@MainActor
struct AiRouterProviderPluginTests {

    @Test("onBoot 把 AiRouter 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = AiRouterProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "airouter")?.providerInfo.id == "airouter")
    }
}
