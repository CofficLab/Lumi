import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderStepFun

@MainActor
struct StepFunProviderPluginTests {

    @Test("onBoot 把 Step Plan 与开放平台供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = StepFunProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 2)
        #expect(manager.provider(id: "stepfun")?.providerInfo.id == "stepfun")
        #expect(manager.provider(id: "stepfun-platform")?.providerInfo.id == "stepfun-platform")
    }

    @Test("两个 Provider 使用各自端点并共享 API Key")
    func providerConfigurationsMatchStepFunChannels() {
        let stepPlan = StepFunProvider()
        let platform = StepFunPlatformProvider()

        #expect(stepPlan.providerInfo.defaultModel == "step-router-v1")
        #expect(stepPlan.providerInfo.modelIDs == ["step-router-v1"])
        #expect(stepPlan.openAIConfiguration?.baseURL == "https://api.stepfun.com/step_plan/v1/chat/completions")

        #expect(platform.providerInfo.defaultModel == "step-5-preview")
        #expect(platform.providerInfo.modelIDs == [
            "step-5-preview",
            "step-3.7-flash",
            "step-3.5-flash-2603",
            "step-3.5-flash",
            "stepaudio-3-chat-preview",
            "stepaudio-2.5-chat",
        ])
        #expect(platform.openAIConfiguration?.baseURL == "https://api.stepfun.com/v1/chat/completions")
        #expect(stepPlan.providerInfo.apiKeyStorageKey == platform.providerInfo.apiKeyStorageKey)
    }
}
