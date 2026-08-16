import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderXiaomi

@MainActor
struct XiaomiProviderPluginTests {

    @Test("onBoot 把 Xiaomi 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = XiaomiProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "xiaomi")?.providerInfo.id == "xiaomi")
        #expect(manager.provider(id: "xiaomi-api")?.providerInfo.id == "xiaomi-api")
    }
}
