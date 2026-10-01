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
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_CommandCodeGoatPlan")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://commandcode.ai"))
    }

    @Test("GoatPlan 基线模型精简：默认模型在列，离线兜底基线保持最小")
    func goatPlanBaseline() throws {
        let provider = GoatPlanProvider()
        let info = provider.providerInfo

        #expect(info.defaultModel == "deepseek/deepseek-v4-flash")
        #expect(info.contains(model: info.defaultModel))

        // 兜底基线保持最小（含默认模型）
        #expect(info.models.count == 4)
        #expect(info.modelIDs.contains(info.defaultModel))
    }

    @Test("GoatPlan 支持远程模型源")
    func goatPlanUsesRemoteModelSource() throws {
        let provider = GoatPlanProvider()

        #expect(provider.usesRemoteModelList == true)
        let source = try #require(provider.remoteModelSource)
        #expect(source.endpoint == URL(string: "https://api.commandcode.ai/provider/v1/models")!)
        #expect(source.apiKeyStorageKey == "DevAssistant_ApiKey_CommandCodeGoatPlan")

        // 初始状态：未拉取过，lastModelSyncDate 为 nil
        #expect(provider.lastModelSyncDate == nil)

        // 默认模型仍可通过动态池访问（合并静态 ∪ 远程；远程未就绪时回退静态基线）
        #expect(provider.availableModels.contains { $0.id == provider.providerInfo.defaultModel })
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