import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderDeepSeek

@MainActor
struct DeepSeekProviderPluginTests {

    @Test("onBoot 把 DeepSeek 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = DeepSeekProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "deepseek")?.providerInfo.id == "deepseek")
        #expect(manager.provider(id: "deepseek-anthropic")?.providerInfo.id == "deepseek-anthropic")
    }
}
