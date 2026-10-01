import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderFeifeimiao

@MainActor
struct FeifeimiaoProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = FeifeimiaoProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.feifeimiao")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.feifeimiao")
        #expect(plugin.metadata.name == "Feifeimiao 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 Feifeimiao 供应商并暴露完整 provider 信息")
    func pluginRegistersFeifeimiaoProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = FeifeimiaoProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "feifeimiao")?.providerInfo)
        #expect(info.id == "feifeimiao")
        #expect(info.displayName == "Feifeimiao")
        #expect(info.description == "LLM API by feifeimiao")
        #expect(info.defaultModel == "gpt-5.5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_Feifeimiao")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://feifeimiao.top"))
    }

    @Test("Feifeimiao 模型清单完整有序且默认模型在内")
    func feifeimiaoModelCatalog() throws {
        let provider = FeifeimiaoProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.3", "gpt-5.2",
        ])
        #expect(info.models.count == 5)
        #expect(info.contains(model: info.defaultModel))

        let top = try #require(info.models.first)
        #expect(top.contextWindowSize == 1_000_000)
        let mini = try #require(info.models.first(where: { $0.id == "gpt-5.4-mini" }))
        #expect(mini.contextWindowSize == 400_000)
    }

    @Test("Feifeimiao 供应商指向 feifeimiao.top 网关端点")
    func feifeimiaoEndpointConfiguration() {
        let provider = FeifeimiaoProvider()

        #expect(provider.providerID == "feifeimiao")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.feifeimiao.top/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = FeifeimiaoProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = FeifeimiaoProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
