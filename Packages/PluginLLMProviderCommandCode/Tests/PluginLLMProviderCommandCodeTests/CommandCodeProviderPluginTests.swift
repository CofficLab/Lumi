import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderCommandCode

@MainActor
struct CommandCodeProviderPluginTests {

    @Test("onBoot 把 GoatPlan 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = CommandCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "goatplan")?.providerInfo.id == "goatplan")
    }
}
