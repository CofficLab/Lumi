import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderKimiCode

@MainActor
struct KimiCodeProviderPluginTests {

    @Test("onBoot 把 KimiCode 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = KimiCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "kimi-code-openai")?.providerInfo.id == "kimi-code-openai")
        #expect(manager.provider(id: "kimi-code-anthropic")?.providerInfo.id == "kimi-code-anthropic")
    }
}
