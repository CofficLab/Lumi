import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderXybbz

@MainActor
struct XybbzProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = XybbzProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.xybbz")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.xybbz")
        #expect(plugin.metadata.name == "Xybbz 供应商")
        #expect(plugin.metadata.description == "注册 XybbzProvider 到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 Xybbz 供应商并暴露完整 provider 信息")
    func pluginRegistersXybbzProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = XybbzProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "xybbz")?.providerInfo)
        #expect(info.id == "xybbz")
        #expect(info.displayName == "Xybbz")
        #expect(info.description == "AI API Gateway by xybbz")
        #expect(info.defaultModel == "gpt-5.5")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_Xybbz")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://xybbz.xyz"))
    }

    @Test("Xybbz 模型清单完整有序且默认模型在内")
    func xybbzModelCatalog() throws {
        let provider = XybbzProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == ["gpt-5.5", "gpt-5.4"])
        #expect(info.models.count == 2)
        #expect(info.contains(model: info.defaultModel))

        for model in info.models {
            #expect(model.contextWindowSize == 1_000_000)
            #expect(model.supportsVision == true)
        }
    }

    @Test("Xybbz 供应商指向 sub2api.xybbz.xyz 端点")
    func xybbzEndpointConfiguration() {
        let provider = XybbzProvider()

        #expect(provider.providerID == "xybbz")
        #expect(provider.openAIConfiguration?.baseURL == "https://sub2api.xybbz.xyz/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = XybbzProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = XybbzProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
