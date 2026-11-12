import os
import KernelCore
import LumiLoggingKit
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI

/// 核心消息渲染器插件（KernelCore 版本）。
///
/// 复刻自旧版 `MessageRendererPlugin`（KernelLumi / LumiPlugin）：
/// - `onBoot` 中把 10 个内置核心渲染器注册进 `MessageRenderingProviding`
///   （优先级与旧版完全一致：turn-completed / status 最高，default-markdown 兜底）；
/// - `onShutdown` 撤回全部注册，保持可卸载。
@MainActor
public final class MessageRendererPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-renderer", category: "MessageRenderer")

    public let id = "CoreMessageRenderer"
    public let order = 10

    public let metadata = PluginMetadata(
        id: "CoreMessageRenderer",
        name: "核心消息渲染器",
        description: "消息渲染：用户/助手/系统/错误/状态/工具消息与工具调用卡片",
        category: .chat,
        stage: .preview,
        policy: .required
    )

    /// 渲染器优先级基数（与旧版一致）。
    public nonisolated static let baseOrder: Int = 10

    private var riskApprovalChatViewModel: RiskApprovalChatViewModel?
    private var capability: MessageRendererCapabilityAdapter?
    private var stateViewModel: MessageRendererStateViewModel?
    private var stateObserver: MessageRendererStateObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any MessageRenderingProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve MessageRenderingProviding from kernel")
            return
        }
        ToolApprovalBridge.shared.start(kernel: kernel)
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .register(ToolApprovalRowRenderer())

        // 组装层创建能力、共享状态与外部状态观察者（开发者模式等）。
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)
        let stateViewModel = MessageRendererStateViewModel()
        let stateObserver = MessageRendererStateObserver(
            capability: capability,
            viewModel: stateViewModel
        )
        self.capability = capability
        self.stateViewModel = stateViewModel
        self.stateObserver = stateObserver

        if let conversations = kernel.resolveProvider((any ConversationManaging).self),
           let toolManager = kernel.resolveProvider((any ToolManagerProviding).self),
           let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            let viewModel = RiskApprovalChatViewModel(
                conversations: conversations,
                toolManager: toolManager,
                agentLoop: kernel.resolveProvider((any AgentLoopProviding).self)
            )
            riskApprovalChatViewModel = viewModel
            chat.addItems([
                ChatSectionItem(
                    id: "CoreMessageRenderer.pending-risk-approval",
                    order: 100,
                    placement: .bottomFixed,
                    showsTrailingDivider: false
                ) { [viewModel] in
                    RiskApprovalChatSectionView(viewModel: viewModel)
                }
            ])
        }
        let base = Self.baseOrder

        // 渲染器实现一律在 `Renderers/Core/` 下，入口只负责注册。
        // 菜单挂在**注册层**而不是各个具体视图里，是因为 V4/V5
        // （ZCode / ChatGPT）用的是独立渲染器，**不走** `MessageViewChrome`；
        // 挂视图内部会漏掉这批行。挂在注册层则 V1–V5 行为完全一致。
        manager.register(
            CoreTurnCompletedRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreContextCompactionRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreAgentLoopRetryRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreGoalTaskContinuationRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreModelSwitchedRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreStatusMessageRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreErrorMessageRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreToolMessageRenderer.item(capability: capability, baseOrder: base)
        )
        manager.register(
            CoreUserMessageRenderer.item(
                capability: capability,
                stateViewModel: stateViewModel,
                baseOrder: base
            )
        )
        manager.register(
            CoreToolStepGroupRenderer.item(
                capability: capability,
                stateViewModel: stateViewModel,
                baseOrder: base
            )
        )
        manager.register(
            CoreAssistantMessageRenderer.item(
                capability: capability,
                stateViewModel: stateViewModel,
                baseOrder: base
            )
        )
        manager.register(
            CoreSystemMessageRenderer.item(capability: capability, baseOrder: base)
        )
        // 兜底渲染器：order 最低，只要没有更高优先级的 renderer 能处理，就由它接管。
        manager.register(
            CoreDefaultMarkdownRenderer.item(capability: capability, baseOrder: base)
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "CoreMessageRenderer.pending-risk-approval")
        riskApprovalChatViewModel?.cancel()
        riskApprovalChatViewModel = nil
        stateObserver?.cancel()
        stateObserver = nil
        stateViewModel = nil
        capability = nil
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .unregister(id: ToolApprovalRowRenderer.id)
        ToolApprovalBridge.shared.stop()
        let manager = kernel.resolveProvider((any MessageRenderingProviding).self)
        for id in CoreMessageRenderer.rendererIDs {
            manager?.unregister(id: id)
        }
    }
}
