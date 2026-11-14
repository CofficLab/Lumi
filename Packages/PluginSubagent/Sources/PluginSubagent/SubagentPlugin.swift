import Foundation
import KernelCore
import os
import PluginToolManager
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI

/// 子代理委托插件（#1313）。
///
/// `onBoot` 把 `run_subagent` 工具注册进工具管理器，并在 ChatToolbar
/// 注册一个子代理运行指示器（有运行中的委托才占位）、注册委托卡片渲染器；
/// `onDisable` / `onShutdown` 一并撤回。工具经 `SubagentConversationBridge`
/// 创建隐藏子会话，在隔离回合里跑完任务后只把结论带回父上下文。
///
/// - Important: 与 FinderPlugin 相同，内核禁用插件时只撤回显式登记的贡献，
///   工具必须由本插件自己在 `onDisable` 里撤回，否则禁用后 LLM 仍能调用。
@MainActor
public final class SubagentPlugin: SuperPlugin {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.subagent",
        category: "Subagent"
    )

    public let id = "com.coffic.lumi.plugin.subagent"

    /// 必须晚于 PluginAgentLoop（order 8）：注册时要解析到真实的
    /// AgentLoopProviding，而不是默认降级实现。
    public let order = 9

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.subagent",
        name: "Subagent",
        description: "Delegate self-contained tasks to isolated subagent conversations and return only their conclusions.",
        category: .core,
        stage: .preview,
        policy: .alwaysOn
    )

    /// 让 onEnable 幂等：内核「曾 Boot 过再启用」只调 onEnable。
    private var isRegistered = false

    private var activityViewModel: SubagentActivityViewModel?

    /// 后台任务登记表（PluginToolManager 注册的内核 Provider）。
    private var backgroundRegistry: BackgroundTaskRegistry?

    /// 登记表完成事件的观察者 ID（注销用）。
    private var backgroundObserverID: UUID?

    /// 后台任务 ID → 子会话：显式停止时据此级联取消子回合。
    private var backgroundChildConversations: [String: UUID] = [:]

    private weak var agentLoop: (any AgentLoopProviding)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        registerContributions(kernel: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerContributions(kernel: kernel)
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterContributions(kernel: kernel)
    }

    // MARK: - Contributions

    private func registerContributions(kernel: KernelCoreContainer) {
        guard !isRegistered else { return }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
        else {
            Self.logger.error("Subagent dependencies not found; run_subagent tool skipped")
            return
        }

        isRegistered = true
        self.agentLoop = agentLoop

        // 后台模式复用 #1307 的登记表；缺席时工具仍注册，后台调用显式失败。
        let registry = kernel.resolveProvider(BackgroundTaskRegistry.self)
        backgroundRegistry = registry
        if let registry {
            // 观察者注册是 actor 隔离的，放到 Task 里完成；
            // 完成事件回到 MainActor 处理（字典与 cancelTurn 都在主线程）。
            Task { @MainActor [weak self] in
                let observerID = await registry.addObserver { [weak self] event in
                    Task { @MainActor [weak self] in
                        self?.handleBackgroundTaskEvent(event)
                    }
                }
                self?.backgroundObserverID = observerID
            }
        }

        toolManager.add(
            RunSubagentTool(
                conversations: conversations,
                messages: messages,
                agentLoop: agentLoop,
                toolManager: toolManager,
                backgroundRegistryProvider: { [weak registry] in registry },
                onBackgroundTaskStarted: { [weak self] taskID, childID in
                    self?.backgroundChildConversations[taskID] = childID
                }
            ),
            pluginID: id
        )

        registerToolbarItem(kernel: kernel, conversations: conversations, toolManager: toolManager)
        registerCardRenderer(kernel: kernel, toolManager: toolManager)
    }

    /// 后台任务结束：显式停止时级联取消子回合。
    ///
    /// 自然完成（completed/failed）时子回合早已结束，无需取消；
    /// 只有 .stopped 意味着进程内任务被外部叫停而子回合可能还在跑。
    private func handleBackgroundTaskEvent(_ event: BackgroundTaskEvent) {
        guard case .finished(let record) = event else { return }
        guard let childID = backgroundChildConversations.removeValue(forKey: record.id) else { return }
        if record.status == .stopped {
            agentLoop?.cancelTurn(in: childID)
        }
    }

    /// ChatToolbar 运行指示器。ChatSection 缺席只影响 UI，不阻止工具注册。
    private func registerToolbarItem(
        kernel: KernelCoreContainer,
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding
    ) {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("ChatSectionProviding not found; subagent toolbar item skipped")
            return
        }

        let viewModel = SubagentActivityViewModel(
            conversations: conversations,
            toolManager: toolManager
        )
        activityViewModel = viewModel

        let itemID = "\(id).toolbar"
        chat.removeBarItem(id: itemID)
        chat.addBarItems([
            ChatSectionBarItem(
                id: itemID,
                order: order,
                placement: .toolbarTrailing
            ) { [weak viewModel] in
                if let viewModel {
                    SubagentActivityToolbarButton(viewModel: viewModel)
                } else {
                    EmptyView()
                }
            },
        ])
    }

    /// 委托卡片渲染器（#1313 Task 6）。缺席只影响卡片呈现，不阻止工具注册。
    private func registerCardRenderer(
        kernel: KernelCoreContainer,
        toolManager: any ToolManagerProviding
    ) {
        guard let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) else {
            Self.logger.error("MessageRenderingProviding not found; subagent card renderer skipped")
            return
        }
        rendering.register(
            SubagentCardRenderer.item(
                order: order + 10,
                toolManagerProvider: { [weak toolManager] in toolManager }
            )
        )
    }

    private func unregisterContributions(kernel: KernelCoreContainer) {
        guard isRegistered else { return }
        isRegistered = false
        if let registry = backgroundRegistry, let observerID = backgroundObserverID {
            Task { await registry.removeObserver(observerID) }
        }
        backgroundObserverID = nil
        backgroundRegistry = nil
        backgroundChildConversations.removeAll()
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
        activityViewModel?.cancel()
        activityViewModel = nil
        kernel.resolveProvider((any MessageRenderingProviding).self)?
            .unregister(id: SubagentTimeline.rendererID)
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: RunSubagentTool.toolName)
    }
}