import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMegaLLM

@MainActor
struct MegaLLMProviderPluginTests {

    @Test("onBoot 把 MegaLLM 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = MegaLLMProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "megallm")?.providerInfo.id == "megallm")
    }
}
