import Foundation
import KernelCore
import ProviderLLMManager

/// FlyMux 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把本供应商的 FlyMuxProvider 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到该供应商。
/// 对应旧版 com.coffic.lumi.plugin.llm-provider.flymux 的 `llmProviders(kernel:)` 贡献职责。
@MainActor
public final class FlyMuxProviderPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.flymux"
    public let order = 100

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMProviderManagerProviding).self) else {
            return
        }
        let providers: [any ManagedLLMProvider] = [FlyMuxProvider()]
        for provider in providers {
            try? manager.register(provider)
        }
    }
}
