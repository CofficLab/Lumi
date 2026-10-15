import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderHyperAPI

@MainActor
struct HyperAPIProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = HyperAPIProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.hyperapi")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.hyperapi")
        #expect(plugin.metadata.name == "HyperAPI 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 HyperAPI 供应商并暴露完整 provider 信息")
    func pluginRegistersHyperAPIProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = HyperAPIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "hyperapi")?.providerInfo)
        #expect(info.id == "hyperapi")
        #expect(info.displayName == "HyperAPI")
        #expect(info.description == "LLM Router by hyperapi.cc")
        #expect(info.defaultModel == "gpt-5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_HyperAPI")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://hyperapi.cc"))
    }

    @Test("HyperAPI 模型清单完整有序且默认模型在内")
    func hyperAPIModelCatalog() throws {
        let provider = HyperAPIProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "gpt-5.1-codex-max", "gpt-5.2-codex", "gpt-5.4-mini",
            "gpt-5", "gpt-5.1-codex-mini", "gpt-5.2", "gpt-5.3-codex",
            "gpt-5.4", "gpt-5-codex", "gpt-5.1", "gpt-5.1-codex",
        ])
        #expect(info.models.count == 11)
        #expect(info.contains(model: info.defaultModel))

        let gpt54 = try #require(info.models.first(where: { $0.id == "gpt-5.4" }))
        #expect(gpt54.contextWindowSize == 1_000_000)
        let gpt5 = try #require(info.models.first(where: { $0.id == "gpt-5" }))
        #expect(gpt5.contextWindowSize == 400_000)
    }

    @Test("HyperAPI 供应商指向 hyperapi.cc 网关端点")
    func hyperAPIEndpointConfiguration() {
        let provider = HyperAPIProvider()

        #expect(provider.providerID == "hyperapi")
        #expect(provider.openAIConfiguration?.baseURL == "https://hyperapi.cc/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = HyperAPIProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = HyperAPIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
