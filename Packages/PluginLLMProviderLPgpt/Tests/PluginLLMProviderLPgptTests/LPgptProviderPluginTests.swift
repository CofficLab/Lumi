import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderLPgpt

@MainActor
struct LPgptProviderPluginTests {

    @Test("onBoot 把 LPgpt 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = LPgptProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "lpgpt")?.providerInfo.id == "lpgpt")
    }
}
