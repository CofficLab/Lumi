import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderDeepSeek

@MainActor
struct DeepSeekProviderPluginTests {

    @Test("onBoot 把 DeepSeek 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = DeepSeekProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        // `DeepSeekAnthropicProvider` 目前被注释掉（生产代码），只注册 1 个供应商。
        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "deepseek")?.providerInfo.id == "deepseek")
    }

    @Test("V4.1 Flash 声明视觉能力")
    func flashModelSupportsVision() throws {
        let provider = DeepSeekProvider()
        let model = provider.providerInfo.models.first { $0.id == "deepseek-flash" }

        #expect(model?.supportsVision == true)
    }
}
