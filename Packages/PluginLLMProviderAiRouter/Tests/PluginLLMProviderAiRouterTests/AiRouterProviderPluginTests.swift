import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderAiRouter

@MainActor
struct AiRouterProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = AiRouterProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.airouter")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.airouter")
        #expect(plugin.metadata.name == "AiRouter 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 AiRouter 供应商并暴露完整 provider 信息")
    func pluginRegistersAiRouterProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = AiRouterProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "airouter")?.providerInfo)
        #expect(info.id == "airouter")
        #expect(info.displayName == "AiRouter")
        #expect(info.description == "LLM Router by airouter.org")
        #expect(info.defaultModel == "gpt-5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_AiRouter")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://airouter.org"))
    }

    @Test("AiRouter 模型清单完整有序且默认模型在内")
    func aiRouterModelCatalog() throws {
        let provider = AiRouterProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "gpt-5.1-codex-max", "gpt-5.2-codex", "gpt-5.4-mini",
            "gpt-5", "gpt-5.1-codex-mini", "gpt-5.2", "gpt-5.3-codex",
            "gpt-5.4", "gpt-5-codex", "gpt-5.1", "gpt-5.1-codex",
        ])
        #expect(info.models.count == 11)
        #expect(info.contains(model: info.defaultModel))

        // gpt-5.4 上下文窗口为 1M，其余为 400k
        let gpt54 = try #require(info.models.first(where: { $0.id == "gpt-5.4" }))
        #expect(gpt54.contextWindowSize == 1_000_000)
        let gpt5 = try #require(info.models.first(where: { $0.id == "gpt-5" }))
        #expect(gpt5.contextWindowSize == 400_000)
    }

    @Test("AiRouter 供应商指向 airouter.org 网关端点")
    func aiRouterEndpointConfiguration() {
        let provider = AiRouterProvider()

        #expect(provider.providerID == "airouter")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.airouter.org/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = AiRouterProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = AiRouterProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
