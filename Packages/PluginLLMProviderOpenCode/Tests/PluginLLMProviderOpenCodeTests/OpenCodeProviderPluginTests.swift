import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderOpenCode

@MainActor
struct OpenCodeProviderPluginTests {

    @Test("onBoot 把 Go 和 Zen 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = OpenCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "opencode-go")?.providerInfo.id == "opencode-go")
        #expect(manager.provider(id: "opencode-zen")?.providerInfo.id == "opencode-zen")
    }
}
