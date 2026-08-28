import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderXybbz

@MainActor
struct XybbzProviderPluginTests {

    @Test("onBoot 把 Xybbz 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = XybbzProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "xybbz")?.providerInfo.id == "xybbz")
    }
}
