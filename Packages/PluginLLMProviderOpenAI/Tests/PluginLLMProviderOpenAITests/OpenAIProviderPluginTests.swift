import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderOpenAI

@MainActor
struct OpenAIProviderPluginTests {

    @Test("onBoot 把 OpenAI 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = OpenAIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "openai")?.providerInfo.id == "openai")
    }
}
