import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderTencent

@MainActor
struct TokenHubProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = TencentProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.tencent")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.tencent")
        #expect(plugin.metadata.name == "腾讯云供应商")
        #expect(plugin.metadata.description == "注册 TokenHubProvider 到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 把腾讯云 TokenHub 供应商注册进管理器并暴露完整信息")
    func pluginRegistersTokenHubProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = TencentProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "tencent")?.providerInfo)
        #expect(info.id == "tencent")
        #expect(info.displayName == "腾讯云 TokenHub")
        #expect(info.description == "Tencent Cloud TokenHub")
        #expect(info.defaultModel == "hy4-preview")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_Tencent")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://cloud.tencent.com/product/tokenhub"))
    }

    @Test("TokenHub 模型清单完整有序且默认模型在内")
    func tokenHubModelCatalog() throws {
        let provider = TokenHubProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "hy4-preview", "hy3", "kimi-k3",
            "kimi-k2.7-code", "kimi-k2.7-code-highspeed", "kimi-k2.5",
            "deepseek-v4-pro-202606", "deepseek-v4-pro-0813", "deepseek-v3.2",
            "glm-5.3", "glm-5.2", "glm-5.1", "glm-5", "glm-5-turbo",
            "minimax-m3", "minimax-m2.7", "qwen3.5-plus",
            "deepseek-v4-flash", "deepseek-v4-flash-0731", "hy-mt2-pro",
            "hy-image-v3", "vidu-image-q2",
            "minimax-video-h3", "pixverse-video-c1", "kling-video-v3",
            "hy-3d-3.1", "hy-3d-3.0", "hy-3d-express",
            "deepseek/deepseek-v4-flash-vision-exp", "hy-vision-2.0-instruct", "glm-5.3-flash",
            "hy-asr-3.0-preview", "minimax-speech-2.8-hd", "minimax-music-v2.6",
        ])
        #expect(info.models.count == 34)
        #expect(info.contains(model: info.defaultModel))

        // 默认模型 hy4-preview 为 1M 上下文
        let first = try #require(info.models.first)
        #expect(first.id == "hy4-preview")
        #expect(first.contextWindowSize == 1_000_000)
    }

    @Test("TokenHubProvider 使用腾讯云 Chat Completions 端点")
    func providerUsesTokenHubEndpoint() {
        let provider = TokenHubProvider()

        #expect(provider.providerID == "tencent")
        #expect(provider.openAIConfiguration?.baseURL == "https://tokenhub.tencentmaas.com/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = TencentProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = TencentProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
