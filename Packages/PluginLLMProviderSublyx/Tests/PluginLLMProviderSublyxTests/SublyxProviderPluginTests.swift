import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSublyx

@MainActor
struct SublyxProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = SublyxProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.sublyx")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.sublyx")
        #expect(plugin.metadata.name == "Sublyx 供应商")
        #expect(plugin.metadata.description == "注册 SublyxProvider 到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 Sublyx 供应商并暴露完整 provider 信息")
    func pluginRegistersSublyxProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = SublyxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "sublyx")?.providerInfo)
        #expect(info.id == "sublyx")
        #expect(info.displayName == "Sublyx")
        #expect(info.description == "GPT API Gateway by Sublyx")
        #expect(info.defaultModel == "gpt-5.5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_Sublyx")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://api.sublyx.org/"))
    }

    @Test("Sublyx 模型清单完整有序且默认模型在内")
    func sublyxModelCatalog() throws {
        let provider = SublyxProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-4o", "gpt-4.1",
        ])
        #expect(info.models.count == 5)
        #expect(info.contains(model: info.defaultModel))

        // gpt-4o 为 128k，其余为 1M
        let gpt4o = try #require(info.models.first(where: { $0.id == "gpt-4o" }))
        #expect(gpt4o.contextWindowSize == 128_000)
        let gpt41 = try #require(info.models.first(where: { $0.id == "gpt-4.1" }))
        #expect(gpt41.contextWindowSize == 1_000_000)
    }

    @Test("Sublyx 供应商指向 sublyx.org 网关端点")
    func sublyxEndpointConfiguration() {
        let provider = SublyxProvider()

        #expect(provider.providerID == "sublyx")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.sublyx.org/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = SublyxProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = SublyxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
