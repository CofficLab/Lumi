import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderCommandCode

@MainActor
struct CommandCodeProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = CommandCodeProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.commandcode")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.commandcode")
        #expect(plugin.metadata.name == "CommandCode 供应商")
        #expect(plugin.metadata.description == "注册 GoatPlan 供应商到 LLM 管理器。")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 GoatPlan 供应商并暴露完整 provider 信息")
    func pluginRegistersGoatPlanProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = CommandCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "goatplan")?.providerInfo)
        #expect(info.id == "goatplan")
        #expect(info.displayName == "CommandCode GoatPlan")
        #expect(info.description == "CommandCode GoatPlan 多模型订阅服务")
        #expect(info.defaultModel == "deepseek/deepseek-v4-flash")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_CommandCodeGoatPlan")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://commandcode.ai"))
    }

    @Test("GoatPlan 模型清单完整有序且默认模型在内")
    func goatPlanModelCatalog() throws {
        let provider = GoatPlanProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "claude-sonnet-5", "claude-sonnet-4-6", "claude-fable-5-1", "claude-fable-5",
            "claude-opus-5", "claude-opus-4-8", "claude-opus-4-7", "claude-haiku-4-5-20251001",
            "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.5", "gpt-5.4",
            "gpt-5.3-codex", "gpt-5.4-mini",
            "deepseek/deepseek-v4-pro", "deepseek/deepseek-v4-flash",
            "deepseek/deepseek-v4-flash-vision-exp", "deepseek/deepseek-v4-flash-fast",
            "deepseek/deepseek-v4.1-flash",
            "moonshotai/Kimi-K3", "moonshotai/Kimi-K2.7-Code", "moonshotai/Kimi-K2.7-Code-Highspeed",
            "moonshotai/Kimi-K2.6", "moonshotai/Kimi-K2.5",
            "z-ai/glm-5.3-flash", "zai-org/GLM-5.3", "zai-org/GLM-5.2", "zai-org/GLM-5.2-Fast",
            "zai-org/GLM-5.1", "zai-org/GLM-5",
            "MiniMaxAI/MiniMax-M3", "MiniMaxAI/MiniMax-M2.7", "MiniMaxAI/MiniMax-M2.5",
            "xiaomi/mimo-v2.5-pro", "xiaomi/mimo-v2.5",
            "Qwen/Qwen3.8-Max-0902", "Qwen/Qwen3.8-Max", "Qwen/Qwen3.8-27B", "Qwen/Qwen3.8-Flash",
            "Qwen/Qwen3.7-Max", "Qwen/Qwen3.7-Plus", "Qwen/Qwen3.7-Flash",
            "Qwen/Qwen3.6-Max-Preview", "Qwen/Qwen3.6-Plus",
            "stepfun/Step-3.7-Flash", "stepfun/Step-3.5-Flash",
            "tencent/hy3-paid", "tencent/hy4-preview",
            "google/gemini-3.8-flash", "google/gemini-3.7-flash", "google/gemini-3.6-flash",
            "google/gemini-3.5-flash", "google/gemini-3.5-flash-lite", "google/gemini-3.1-flash-lite",
            "meituan/LongCat-2.0:free", "sakana/fugu-ultra", "nvidia/nemotron-3-ultra-550b-a55b",
            "thinkingmachines/inkling", "thinkingmachines/inkling-small",
            "poolside/laguna-s-2.1-free", "inclusionai/ling-3.0-flash-sante:free",
            "meta/muse-spark-1.1", "meta/muse-spark-1.2", "meta/muse-spark-1.2-contributor",
            "meta/muse-spark-1.3", "meta/muse-spark-1.3-contributor",
            "xai/grok-4.5", "xai/grok-4.6",
        ])
        #expect(info.models.count == 69)
        #expect(info.contains(model: info.defaultModel))

        // 默认模型上下文窗口为 1M
        let flash = try #require(info.models.first(where: { $0.id == "deepseek/deepseek-v4-flash" }))
        #expect(flash.contextWindowSize == 1_000_000)
        // 唯一显式声明支持视觉的模型
        let vision = try #require(info.models.first(where: { $0.id == "deepseek/deepseek-v4.1-flash" }))
        #expect(vision.supportsVision == true)
    }

    @Test("GoatPlan 供应商指向 commandcode 网关端点")
    func goatPlanEndpointConfiguration() {
        let provider = GoatPlanProvider()

        #expect(provider.providerID == "goatplan")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.commandcode.ai/provider/v1/chat/completions")
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = CommandCodeProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = CommandCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
