import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderZhipu

@MainActor
struct ZhipuProviderPluginTests {

    @Test("onBoot 把 Zhipu 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = ZhipuProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "zhipu-api")?.providerInfo.id == "zhipu-api")
        #expect(manager.provider(id: "zhipu")?.providerInfo.id == "zhipu")
    }
}
