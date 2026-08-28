import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderFeifeimiao

@MainActor
struct FeifeimiaoProviderPluginTests {

    @Test("onBoot 把 Feifeimiao 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = FeifeimiaoProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "feifeimiao")?.providerInfo.id == "feifeimiao")
    }
}
