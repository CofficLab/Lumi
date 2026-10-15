import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderAnthropic

@MainActor
struct AnthropicProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = AnthropicProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.anthropic")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.anthropic")
        #expect(plugin.metadata.name == "Anthropic 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 Anthropic 供应商并暴露完整 provider 信息")
    func pluginRegistersAnthropicProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = AnthropicProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "anthropic")?.providerInfo)
        #expect(info.id == "anthropic")
        #expect(info.displayName == "Anthropic")
        #expect(info.description == "Claude AI by Anthropic")
        #expect(info.defaultModel == "claude-sonnet-4-20250514")
        #expect(info.apiFormat.rawValue == "anthropic")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_Anthropic")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://www.anthropic.com/"))
    }

    @Test("Anthropic 模型清单完整有序且默认模型在内")
    func anthropicModelCatalog() throws {
        let provider = AnthropicProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "claude-sonnet-4-20250514",
            "claude-opus-4-20250514",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-sonnet-20240620",
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
        ])
        #expect(info.models.count == 7)
        #expect(info.contains(model: info.defaultModel))

        // Claude 全系均为 200k 上下文且支持视觉
        for model in info.models {
            #expect(model.contextWindowSize == 200_000)
            #expect(model.supportsVision == true)
        }
    }

    @Test("Anthropic 供应商指向官方 Messages 端点")
    func anthropicEndpointConfiguration() {
        let provider = AnthropicProvider()

        #expect(provider.providerID == "anthropic")
        #expect(provider.anthropicConfiguration?.baseURL == "https://api.anthropic.com/v1/messages")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = AnthropicProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = AnthropicProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
