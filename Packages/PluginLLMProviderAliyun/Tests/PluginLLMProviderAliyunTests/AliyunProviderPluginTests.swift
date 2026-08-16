import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderAliyun

@MainActor
struct AliyunProviderPluginTests {

    @Test("onBoot 把 Aliyun 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = AliyunProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "aliyun")?.providerInfo.id == "aliyun")
        #expect(manager.provider(id: "aliyun-tokenplan")?.providerInfo.id == "aliyun-tokenplan")
    }
}
