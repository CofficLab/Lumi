import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderFlyMux

@MainActor
struct FlyMuxProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = FlyMuxProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.flymux")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.flymux")
        #expect(plugin.metadata.name == "FlyMux 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 FlyMux 供应商并暴露完整 provider 信息")
    func pluginRegistersFlyMuxProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = FlyMuxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "flymux")?.providerInfo)
        #expect(info.id == "flymux")
        #expect(info.displayName == "FlyMux")
        #expect(info.description == "LLM API Gateway by FlyMux")
        #expect(info.defaultModel == "gpt-5.5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_FlyMux")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://flymux.ai"))
    }

    @Test("FlyMux 模型清单完整有序且默认模型在内")
    func flyMuxModelCatalog() throws {
        let provider = FlyMuxProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == ["gpt-5.5", "gpt-5.4"])
        #expect(info.models.count == 2)
        #expect(info.contains(model: info.defaultModel))

        for model in info.models {
            #expect(model.contextWindowSize == 1_000_000)
            #expect(model.supportsVision == true)
        }
    }

    @Test("FlyMux 供应商指向 flymux.ai 网关端点")
    func flyMuxEndpointConfiguration() {
        let provider = FlyMuxProvider()

        #expect(provider.providerID == "flymux")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.flymux.ai/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = FlyMuxProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = FlyMuxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
