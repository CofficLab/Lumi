import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

@MainActor
struct MiniMaxProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = MiniMaxProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.minimax")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.minimax")
        #expect(plugin.metadata.name == "MiniMax 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 MiniMax OpenAI 协议供应商")
    func pluginRegistersMiniMaxProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "minimax-tokenplan")?.providerInfo)
        #expect(info.id == "minimax-tokenplan")
        #expect(info.displayName == "MiniMax (OpenAI)")
        #expect(info.description == "MiniMax Token Plan via OpenAI-compatible API")
        #expect(info.defaultModel == "MiniMax-M2.7")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_MiniMax")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://platform.minimaxi.com/"))
    }

    @Test("MiniMax 共享模型清单完整有序")
    func miniMaxModelCatalog() throws {
        let provider = MiniMaxOpenAIProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed",
            "MiniMax-M2.5", "MiniMax-M2.5-highspeed",
        ])
        #expect(info.models.count == 5)
        #expect(info.contains(model: info.defaultModel))

        // 三个协议变体共享同一批模型
        #expect(MiniMaxVendorModels.all.count == 5)
        #expect(MiniMaxVendorModels.all.map(\.id) == info.modelIDs)

        let m3 = try #require(info.models.first(where: { $0.id == "MiniMax-M3" }))
        #expect(m3.contextWindowSize == 1_000_000)
        #expect(m3.supportsVision == true)
        let m25 = try #require(info.models.first(where: { $0.id == "MiniMax-M2.5" }))
        #expect(m25.contextWindowSize == 204_800)
        #expect(m25.supportsVision == false)
    }

    @Test("MiniMax 供应商指向 minimaxi.com 端点")
    func miniMaxEndpointConfiguration() {
        let provider = MiniMaxOpenAIProvider()

        #expect(provider.providerID == "minimax-tokenplan")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.minimaxi.com/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = MiniMaxProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
