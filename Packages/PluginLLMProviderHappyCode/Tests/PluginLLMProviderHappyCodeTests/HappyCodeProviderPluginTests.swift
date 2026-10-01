import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderHappyCode

@MainActor
struct HappyCodeProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = HappyCodeProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.happycode")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.happycode")
        #expect(plugin.metadata.name == "HappyCode 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 HappyCode 供应商并暴露完整 provider 信息")
    func pluginRegistersHappyCodeProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = HappyCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "happycode")?.providerInfo)
        #expect(info.id == "happycode")
        #expect(info.displayName == "HappyCode")
        #expect(info.description == "AI API Gateway by HappyCode")
        #expect(info.defaultModel == "gpt-5.5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_HappyCode")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://happycode.vip"))
    }

    @Test("HappyCode 仅暴露单个默认模型")
    func happyCodeModelCatalog() throws {
        let provider = HappyCodeProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == ["gpt-5.5"])
        #expect(info.models.count == 1)
        #expect(info.contains(model: info.defaultModel))

        let only = try #require(info.models.first)
        #expect(only.contextWindowSize == 1_000_000)
        #expect(only.supportsVision == true)
    }

    @Test("HappyCode 供应商指向 happycode.vip 端点")
    func happyCodeEndpointConfiguration() {
        let provider = HappyCodeProvider()

        #expect(provider.providerID == "happycode")
        #expect(provider.openAIConfiguration?.baseURL == "https://happycode.vip/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = HappyCodeProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = HappyCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
