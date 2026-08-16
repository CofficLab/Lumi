import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderStepFun

@MainActor
struct StepFunProviderPluginTests {

    @Test("onBoot 把 StepFun 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = StepFunProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "stepfun")?.providerInfo.id == "stepfun")
    }
}
