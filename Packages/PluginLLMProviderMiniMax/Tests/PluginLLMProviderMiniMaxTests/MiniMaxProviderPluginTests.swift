import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

@MainActor
struct MiniMaxProviderPluginTests {

    @Test("onBoot 把 MiniMax 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "minimax-tokenplan")?.providerInfo.id == "minimax-tokenplan")
    }
}
