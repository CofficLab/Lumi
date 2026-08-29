import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderTencent

@MainActor
struct TokenHubProviderPluginTests {

    @Test("onBoot 把腾讯云 TokenHub 供应商注册进管理器")
    func pluginRegistersProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = TencentProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "tencent")?.providerInfo.id == "tencent")
        #expect(manager.provider(id: "tencent")?.providerInfo.defaultModel == "hy4-preview")
        #expect(manager.provider(id: "tencent")?.providerInfo.modelIDs == ["hy4-preview"])
    }

    @Test("TokenHubProvider 使用腾讯云 Chat Completions 端点")
    func providerUsesTokenHubEndpoint() {
        let provider = TokenHubProvider()

        #expect(provider.providerID == "tencent")
        #expect(provider.openAIConfiguration?.baseURL == "https://tokenhub.tencentmaas.com/v1/chat/completions")
    }
}
