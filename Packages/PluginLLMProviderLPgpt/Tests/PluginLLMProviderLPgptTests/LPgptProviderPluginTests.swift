import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderLPgpt

@MainActor
struct LPgptProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = LPgptProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.lpgpt")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.lpgpt")
        #expect(plugin.metadata.name == "LPgpt 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 LPgpt 供应商并暴露完整 provider 信息")
    func pluginRegistersLPgptProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = LPgptProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "lpgpt")?.providerInfo)
        #expect(info.id == "lpgpt")
        #expect(info.displayName == "LPgpt")
        #expect(info.description == "Free LLM Gateway by lpgpt.us")
        #expect(info.defaultModel == "gpt-5.4")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_LPgpt")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://lpgpt.us"))
    }

    @Test("LPgpt 模型清单完整有序且默认模型在内")
    func lpgptModelCatalog() throws {
        let provider = LPgptProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == ["gpt-5.4", "gpt-5.5"])
        #expect(info.models.count == 2)
        #expect(info.contains(model: info.defaultModel))

        for model in info.models {
            #expect(model.contextWindowSize == 1_000_000)
            #expect(model.supportsVision == true)
        }
    }

    @Test("LPgpt 供应商指向 lpgpt.us 网关端点")
    func lpgptEndpointConfiguration() {
        let provider = LPgptProvider()

        #expect(provider.providerID == "lpgpt")
        #expect(provider.openAIConfiguration?.baseURL == "https://lpgpt.us/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = LPgptProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = LPgptProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
