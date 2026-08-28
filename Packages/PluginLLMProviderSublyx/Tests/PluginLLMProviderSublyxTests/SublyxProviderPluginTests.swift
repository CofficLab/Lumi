import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSublyx

@MainActor
struct SublyxProviderPluginTests {

    @Test("onBoot 把 Sublyx 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = SublyxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "sublyx")?.providerInfo.id == "sublyx")
    }
}
