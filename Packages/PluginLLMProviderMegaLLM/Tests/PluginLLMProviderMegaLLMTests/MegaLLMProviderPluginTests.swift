import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMegaLLM

@MainActor
struct MegaLLMProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = MegaLLMProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.megallm")
        #expect(plugin.order == 1000)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.megallm")
        #expect(plugin.metadata.name == "MegaLLM 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 MegaLLM 供应商并暴露完整 provider 信息")
    func pluginRegistersMegaLLMProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MegaLLMProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "megallm")?.providerInfo)
        #expect(info.id == "megallm")
        #expect(info.displayName == "MegaLLM")
        #expect(info.description == "MegaLLM AI")
        #expect(info.defaultModel == "gpt-5-mini")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_MegaLLM")
        #expect(info.providerType.rawValue == "relay")
        #expect(info.websiteURL == URL(string: "https://megallm.io"))
    }

    @Test("MegaLLM 模型清单完整有序且默认模型在内")
    func megaLLMModelCatalog() throws {
        let provider = MegaLLMProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "alibaba-qwen3.5-397b",
            "claude-haiku-4-5-20251001",
            "claude-opus-4-5-20251101",
            "claude-opus-4-6",
            "claude-sonnet-4-5-20250929",
            "claude-sonnet-4-6",
            "deepseek-ai/deepseek-v3.1",
            "grok-4.1-fast-reasoning",
            "gpt-5-mini",
            "gpt-5.3-codex",
            "llama3.3-70b-instruct",
            "minimaxai/minimax-m2.1",
            "newclaude-opus-4-6",
        ])
        #expect(info.models.count == 13)
        #expect(info.contains(model: info.defaultModel))

        // 视觉能力按模型区分
        let qwen = try #require(info.models.first(where: { $0.id == "alibaba-qwen3.5-397b" }))
        #expect(qwen.supportsVision == false)
        let claude = try #require(info.models.first(where: { $0.id == "claude-sonnet-4-6" }))
        #expect(claude.supportsVision == true)
    }

    @Test("MegaLLM 供应商指向 ai.megallm.io 网关端点")
    func megaLLMEndpointConfiguration() {
        let provider = MegaLLMProvider()

        #expect(provider.providerID == "megallm")
        #expect(provider.openAIConfiguration?.baseURL == "https://ai.megallm.io/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = MegaLLMProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MegaLLMProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
