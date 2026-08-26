import Foundation
import KernelCore
import KitLLM
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// AgentLoop 插件
///
/// 使用自定义的 AgentLoopProvider 替换默认的 DefaultAgentLoopProvider。
/// AgentLoopProvider 负责 LLM step、回合状态机和结果回写；工具调用通过事件
/// 交给 PluginToolManager，授权 UI 通过 AgentLoop 的恢复接口继续回合。
///
/// 执行顺序：order = 8
/// - 必须在 MessageSenderPlugin (order=9) 之前执行，因为后者依赖 AgentLoopProviding
/// - 在 DefaultProviderFactory 注册默认实现之后执行
/// - 使用 unregisterProvider + registerProvider 模式替换默认实现
@MainActor
public final class PluginAgentLoop: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    public let id = "com.coffic.lumi.plugin.agent-loop"
    public let order = 8
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.agent-loop",
        name: "Plugin Agent Loop",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private var messageObserver: (any MessageInsertedObserverHandle)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 获取必需依赖
        guard let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.emoji)MessageManaging not found, skip AgentLoop replacement")
            return
        }
        guard let llmManager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.emoji)LLMManaging not found, skip AgentLoop replacement")
            return
        }
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.emoji)ToolManagerProviding not found, skip AgentLoop replacement")
            return
        }
        guard let streaming = kernel.resolveProvider((any MessageStreamingProviding).self) else {
            Self.logger.error("\(Self.emoji)MessageStreamingProviding not found, skip AgentLoop replacement")
            return
        }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.emoji)ConversationManaging not found, skip AgentLoop replacement")
            return
        }

        // 2. 创建自定义实现
        let agentLoop = AgentLoopManager(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )
        agentLoop.setLifecycleHooks(kernel.resolveProvider((any LifecycleHooksProviding).self))

        // 3. 注销默认的 AgentLoopProviding
        kernel.unregisterProvider((any AgentLoopProviding).self)

        // 5. 注册自定义实现（不转发 objectWillChange，与默认注册保持一致）
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop, forwardsObjectWillChange: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        messageObserver?.cancel()
        messageObserver = nil
        toolManagerObserver?.cancel()
        toolManagerObserver = nil
        // 插件卸载时，内核会自动按归属移除 Provider
    }

    /// 所有 Provider 完成 Boot 后，监听用户消息并启动 Agent 回合。
    ///
    /// MessageSender 只负责把 user message 写入 MessageManaging；回合的启动
    /// 由本插件通过消息事件完成，避免发送器和 AgentLoop 之间的直接调用。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.emoji)MessageManaging or AgentLoopProviding not found, skip message subscription")
            return
        }

        messageObserver = messages.addMessageInsertedObserver { [weak agentLoop] message, conversationID in
            guard message.role == .user else { return }
            guard let agentLoop else {
                Self.logger.error("\(Self.emoji)无法处理用户消息事件：AgentLoopProvider 已释放")
                return
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)message event starts turn conversation=\(conversationID.uuidString.prefix(8))")
            }
            Task { @MainActor in
                guard !agentLoop.isRunning(for: conversationID) else { return }
                do {
                    _ = try await agentLoop.runTurn(in: conversationID)
                } catch {
                    Self.logger.error("\(Self.emoji)event-driven turn failed: \(error.localizedDescription)")
                }
            }
        }
        toolManagerObserver = toolManager.addToolManagerObserver { [weak agentLoop] event in
            guard let agentLoop else {
                Self.logger.error("\(Self.emoji)无法处理 ToolManager 事件：AgentLoopProvider 已释放")
                return
            }
            if case let .batchCompleted(conversationID, turnID, _, results) = event {
                if Self.verbose {
                    Self.logger.info("\(Self.t)🍋 tool batch event received conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID?.uuidString.prefix(8) ?? "nil"), results=\(results.count)")
                }
            }
            // ToolManager 事件已经在 MainActor 上分发，直接推进回合状态机，
            // 避免批次完成后再异步调度导致下一轮请求被延迟或丢失。
            guard let agentLoop = agentLoop as? AgentLoopManager else {
                Self.logger.error("\(Self.emoji)无法处理 ToolManager 事件：AgentLoopProvider 不是 AgentLoopManager")
                return
            }
            agentLoop.handleToolManagerEvent(event)
        }
    }
}
