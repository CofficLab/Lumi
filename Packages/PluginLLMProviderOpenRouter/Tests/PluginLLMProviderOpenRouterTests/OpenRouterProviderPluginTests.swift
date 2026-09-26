import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderOpenRouter

@MainActor
struct OpenRouterProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = OpenRouterProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.openrouter")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.openrouter")
        #expect(plugin.metadata.name == "OpenRouter 供应商")
        #expect(plugin.metadata.description == "注册 OpenRouterProvider 到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 OpenRouter 供应商并暴露完整 provider 信息")
    func pluginRegistersOpenRouterProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = OpenRouterProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "openrouter")?.providerInfo)
        #expect(info.id == "openrouter")
        #expect(info.displayName == "OpenRouter")
        #expect(info.description == "Multi-Provider LLM Router")
        #expect(info.defaultModel == "alibaba/qwen3.5-397b")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_OpenRouter")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://openrouter.ai/"))
    }

    @Test("OpenRouter 模型清单完整有序且默认模型在内")
    func openRouterModelCatalog() throws {
        let provider = OpenRouterProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "alibaba/qwen3.5-397b",
            "anthropic/claude-haiku-4-5-20251001",
            "anthropic/claude-opus-4-5-20251101",
            "anthropic/claude-sonnet-4-5-20250929",
            "bytedance-seed/seedream-4.5",
            "deepseek/deepseek-v3.1",
            "google/gemma-3-27b-it:free",
            "google/gemini-pro-2.5",
            "meta-llama/llama-3.3-70b-instruct",
            "minimax/minimax-m2.1",
            "minimax/minimax-m2.5:free",
            "nvidia/nemotron-3-super-120b-a12b:free",
            "openai/gpt-4o",
            "openai/gpt-5",
            "openai/gpt-5-mini",
            "openai/gpt-oss-20b:free",
            "qwen/qwen3.6-plus",
            "stepfun/step-3.5-flash:free",
            "z-ai/glm-4.5-air:free",
        ])
        #expect(info.models.count == 19)
        #expect(info.contains(model: info.defaultModel))

        let gpt4o = try #require(info.models.first(where: { $0.id == "openai/gpt-4o" }))
        #expect(gpt4o.contextWindowSize == 128_000)
        #expect(gpt4o.supportsVision == true)
    }

    @Test("OpenRouter 供应商指向 openrouter.ai 端点")
    func openRouterEndpointConfiguration() {
        let provider = OpenRouterProvider()

        #expect(provider.providerID == "openrouter")
        #expect(provider.openAIConfiguration?.baseURL == "https://openrouter.ai/api/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = OpenRouterProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = OpenRouterProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
