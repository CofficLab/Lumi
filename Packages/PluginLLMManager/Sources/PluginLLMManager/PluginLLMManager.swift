import Foundation
import KernelCore
import os
import PluginLLMProviderSettings
import ProviderLLMManager
import ProviderMessageRendering
import ProviderOnboarding
import KitLLM
import KitSuperLog

/// LLM 供应商管理器插件。
///
/// 替换 `DefaultProviderFactory` 预注册的 `DefaultLLMManager`：在 `onBoot`
/// 中把自研的 `CustomLLMManager` 注册为 `LLMManaging`，让所有后续解析
/// `LLMManaging` 的插件（供应商注册 order=100、AgentLoop order=8、模型选择
/// UI）统一使用本插件提供的实现。
///
/// 执行顺序：order = 5
/// - 必须先于 `PluginAgentLoop`（order=8）：后者 onBoot 时
///   `resolveProvider((any LLMManaging).self)` 注入 AgentLoop，需拿到本实现；
/// - 必须先于各供应商插件（order=100）：供应商需注册进本插件的管理器。
@MainActor
public final class PluginLLMManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-manager", category: "Plugin")
    public nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-manager"
    public let order = 5
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-manager",
        name: "Plugin LLM Manager",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    /// onBoot 创建并注册的 LLMManaging 实现。
    private var manager: CustomLLMManager?
    /// 本插件的最小供应商能力，供 ViewModel/渲染器使用。
    private var capability: LLMManagerCapabilityAdapter?

    public func onBoot(kernel: KernelCoreContainer) throws {
        let manager = CustomLLMManager()
        self.manager = manager
        let capability = LLMManagerCapabilityAdapter(manager: manager)
        self.capability = capability

        // 1. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any LLMManaging).self)

        // 2. 注册本插件实现。消费者直接观察 LLMManaging 的精准状态接口。
        try kernel.registerProvider((any LLMManaging).self, manager)

        // 3. 注册 API Key 相关消息渲染器（order 350/340，优先于 core-error-message 的 300）。
        if let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) {
            rendering.register(APIKeyMissingRenderer.item(capability: capability))
            rendering.register(APIKeyAccessFailedRenderer.item(capability: capability))
            if Self.verbose {
                Self.logger.info("\(Self.t)registered API Key message renderers (missing / access-failed)")
            }
        } else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)MessageRenderingProviding not resolved, API Key renderers skipped")
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)registered CustomLLMManager as LLMManaging")
        }
    }

    private static let onboardingPageID = "onboarding-ai-setup"

    /// 对话绑定的供应商/模型通过 `LLMRequest.providerID` 显式传递，避免
    /// 切换对话时改写全局选中状态；未绑定对话才使用全局选中项。
    ///
    /// 自定义供应商 Store 由 `LLMProviderSettingsPlugin`（order=100）创建，
    /// `onReady` 在所有 `onBoot` 完成后执行，此时 Store 已就绪。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let manager else { return }

        let onboarding = kernel.resolveProvider((any OnboardingProviding).self)
        let storeProvider = kernel.resolveProvider((any UserDefinedCloudProviderStoreProviding).self)

        // 如果 onboarding 不可用，无法注册页面
        guard let onboarding else {
            if Self.verbose {
                Self.logger.info("\(Self.t)OnboardingProviding not resolved, onboarding page skipped")
            }
            return
        }

        let customStore = storeProvider?.store
        let resolvedCapability = capability ?? LLMManagerCapabilityAdapter(manager: manager)

        if customStore == nil, Self.verbose {
            Self.logger.info("\(Self.t)UserDefinedCloudProviderStore not resolved, onboarding page registered without custom provider support")
        }

        onboarding.register(
            OnboardingPageItem(
                id: Self.onboardingPageID,
                title: LumiPluginLocalization.string("Set up your AI provider", bundle: .module)
            ) { [resolvedCapability] in
                let viewModel = AISetupViewModel(
                    capability: resolvedCapability,
                    customProviderStore: customStore
                )
                AISetupPage(viewModel: viewModel)
            }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let onboarding = kernel.resolveProvider((any OnboardingProviding).self) {
            onboarding.unregister(id: Self.onboardingPageID)
        }
        capability = nil
        manager = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
