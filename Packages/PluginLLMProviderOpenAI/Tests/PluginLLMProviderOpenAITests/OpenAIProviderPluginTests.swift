import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderOpenAI

@MainActor
struct OpenAIProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = OpenAIProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.openai")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.openai")
        #expect(plugin.metadata.name == "OpenAI 供应商")
        #expect(plugin.metadata.description == "注册 OpenAIProvider 到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 OpenAI 供应商并暴露完整 provider 信息")
    func pluginRegistersOpenAIProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = OpenAIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "openai")?.providerInfo)
        #expect(info.id == "openai")
        #expect(info.displayName == "OpenAI")
        #expect(info.description == "GPT by OpenAI")
        #expect(info.defaultModel == "gpt-4o")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_OpenAI")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://openai.com/"))
    }

    @Test("OpenAI 模型清单完整有序且默认模型在内")
    func openAIModelCatalog() throws {
        let provider = OpenAIProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "gpt-5", "gpt-5-mini", "gpt-4o", "gpt-4o-mini",
            "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo",
        ])
        #expect(info.models.count == 7)
        #expect(info.contains(model: info.defaultModel))

        // 关键模型的上下文窗口与视觉能力
        let gpt4o = try #require(info.models.first(where: { $0.id == "gpt-4o" }))
        #expect(gpt4o.contextWindowSize == 128_000)
        #expect(gpt4o.supportsVision == true)

        let gpt4 = try #require(info.models.first(where: { $0.id == "gpt-4" }))
        #expect(gpt4.contextWindowSize == 8_192)
        #expect(gpt4.supportsVision == false)

        let gpt35 = try #require(info.models.first(where: { $0.id == "gpt-3.5-turbo" }))
        #expect(gpt35.contextWindowSize == 16_385)
    }

    @Test("OpenAI 供应商指向官方 Chat Completions 端点")
    func openAIEndpointConfiguration() {
        let provider = OpenAIProvider()

        #expect(provider.providerID == "openai")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.openai.com/v1/chat/completions")
        #expect(provider.openAIConfiguration?.includeUsageInStreamOptions == true)
        #expect(provider.openAIConfiguration?.returnsEmptyChunkWhenNoDelta == false)
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = OpenAIProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = OpenAIProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
