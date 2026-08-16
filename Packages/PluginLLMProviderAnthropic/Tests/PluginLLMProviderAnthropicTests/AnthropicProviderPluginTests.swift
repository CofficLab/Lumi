import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderAnthropic

@MainActor
struct AnthropicProviderPluginTests {

    @Test("onBoot 把 Anthropic 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = AnthropicProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "anthropic")?.providerInfo.id == "anthropic")
    }
}
