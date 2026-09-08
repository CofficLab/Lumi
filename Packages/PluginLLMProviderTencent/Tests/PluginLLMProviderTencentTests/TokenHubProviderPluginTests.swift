import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderTencent

@MainActor
struct TokenHubProviderPluginTests {

    @Test("onBoot 把腾讯云 TokenHub 供应商注册进管理器")
    func pluginRegistersProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = TencentProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "tencent")?.providerInfo.id == "tencent")
        #expect(manager.provider(id: "tencent")?.providerInfo.defaultModel == "hy4-preview")
        #expect(manager.provider(id: "tencent")?.providerInfo.modelIDs == [
            "hy4-preview", "hy3", "kimi-k3", "deepseek-v4-pro-202606", "deepseek-v4-pro-0813", "glm-5.3", "glm-5.2", "glm-5-turbo", "minimax-m3",
            "deepseek-v4-flash-0731", "hy-image-v3", "vidu-image-q2", "minimax-video-h3",
            "pixverse-video-c1", "kling-video-v3", "hy-3d-3.1", "hy-3d-3.0", "hy-3d-express",
            "deepseek/deepseek-v4-flash-vision-exp", "hy-vision-2.0-instruct", "glm-5.3-flash",
            "hy-asr-3.0-preview", "minimax-speech-2.8-hd", "minimax-music-v2.6",
        ])
        #expect(manager.provider(id: "tencent")?.providerInfo.models.first?.contextWindowSize == 1_000_000)
    }

    @Test("TokenHubProvider 使用腾讯云 Chat Completions 端点")
    func providerUsesTokenHubEndpoint() {
        let provider = TokenHubProvider()

        #expect(provider.providerID == "tencent")
        #expect(provider.openAIConfiguration?.baseURL == "https://tokenhub.tencentmaas.com/v1/chat/completions")
    }
}
