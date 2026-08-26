import Foundation
import KernelCore
import os
import ProviderConversation
import ProviderLLMManager
import ProviderMessageRendering
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

    /// onBoot 创建并注册的 LLMManaging 实现（observer 回调需要它做同步）。
    private var manager: CustomLLMManager?
    /// 当前对话变化观察令牌（onReady 注册,onShutdown 注销）。
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    /// 当前对话变化回调里用到的会话管理器。
    private var conversations: (any ConversationManaging)?

    public func onBoot(kernel: KernelCoreContainer) throws {
        let manager = CustomLLMManager()
        self.manager = manager

        // 1. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any LLMManaging).self)

        // 2. 注册本插件实现。消费者直接观察 LLMManaging 的精准状态接口。
        try kernel.registerProvider((any LLMManaging).self, manager)

        // 3. 注册 API Key 相关消息渲染器（order 350/340，优先于 core-error-message 的 300）。
        if let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) {
            rendering.register(APIKeyMissingRenderer.item(manager: manager))
            rendering.register(APIKeyAccessFailedRenderer.item(manager: manager))
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

    /// 全部插件 `onBoot` 完成后执行：监听「当前对话变化」，并把该对话绑定的
    /// 供应商/模型同步为本插件的当前选中值（`LLMManaging.selectedProviderID/selectedModel`）。
    ///
    /// 不能在 `onBoot`(order=5) 里注册——此时 `ConversationManaging` 还是
    /// `ProviderFactory` 预注册的内存默认版，`PluginConversationManager`(order=7)
    /// 稍后会替换为持久化实现，监听挂在旧实例上会收不到任何切换事件。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)ConversationManaging not resolved, skip selected-conversation observer")
            }
            return
        }
        guard let manager else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)manager not initialized, skip selected-conversation observer")
            }
            return
        }
        self.conversations = conversations

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] conversationID in
            guard let self, let manager = self.manager else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)selected conversation changed: \(conversationID?.uuidString ?? "nil")")
            }
            self.syncSelectionFromConversation(conversationID, manager: manager)
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)registered selected-conversation observer")
        }

        // 启动兜底：立即按当前会话同步一次,避免第一发消息仍用旧全局选中。
        syncSelectionFromConversation(conversations.selectedConversationID, manager: manager)
    }

    /// 读取会话绑定的供应商/模型,更新为本插件（LLMManaging）的当前选中值。
    ///
    /// 会话未绑定（nil/空）时保持现状不动；供应商未注册时 `select` 静默忽略,
    /// 不会破坏现有选中。
    private func syncSelectionFromConversation(_ conversationID: UUID?, manager: CustomLLMManager) {
        guard let conversationID,
              let providerID = conversations?.providerID(for: conversationID),
              !providerID.isEmpty else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)conversation has no provider binding, keep current selection")
            }
            return
        }
        let modelName = conversations?.modelName(for: conversationID)
        manager.select(providerID: providerID, model: modelName)
        if Self.verbose {
            Self.logger.info("\(Self.t)synced selection from conversation: provider=\(providerID, privacy: .public), model=\(modelName ?? "nil", privacy: .public)")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        conversations = nil
        manager = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
