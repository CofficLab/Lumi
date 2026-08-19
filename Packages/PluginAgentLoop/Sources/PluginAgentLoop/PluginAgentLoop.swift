import Foundation
import KernelCore
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// AgentLoop 插件
///
/// 使用自定义的 AgentLoopProvider 替换默认的 DefaultAgentLoopProvider。
/// AgentLoopProvider 完整实现了回合循环逻辑（LLM 调用、工具执行、
/// 授权挂起/恢复），而非简单转发到 DefaultAgentLoopProvider。
///
/// 执行顺序：order = 8
/// - 必须在 MessageSenderPlugin (order=9) 之前执行，因为后者依赖 AgentLoopProviding
/// - 在 DefaultProviderFactory 注册默认实现之后执行
/// - 使用 unregisterProvider + registerProvider 模式替换默认实现
@MainActor
public final class PluginAgentLoop: SuperPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"

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
        let agentLoop = AgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )

        // 3. 事件桥接：发布到 NotificationCenter（对齐 ProviderFactory.bridge 通知名）
        agentLoop.setEventHandler { event in
            Self.postNotification(for: event)
        }

        // 4. 注销默认的 AgentLoopProviding
        kernel.unregisterProvider((any AgentLoopProviding).self)

        // 5. 注册自定义实现（不转发 objectWillChange，与默认注册保持一致）
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop, forwardsObjectWillChange: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 插件卸载时，内核会自动按归属移除 Provider
    }

    // MARK: - Notification Bridge

    /// 把 `AgentLoopEvent` 桥接到旧版 NotificationCenter，
    /// 通知名与 `ProviderFactory.bridge` 完全一致。
    private static func postNotification(for event: AgentLoopEvent) {
        switch event {
        case let .turnStarted(conversationID, turnID):
            NotificationCenter.default.post(
                name: .lumiTurnStarted,
                object: nil,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID,
                ]
            )
        case let .messageSaved(conversationID, messageID, role):
            NotificationCenter.default.post(
                name: .lumiMessageSaved,
                object: nil,
                userInfo: [
                    "messageID": messageID,
                    "conversationID": conversationID,
                    "role": role,
                ]
            )
        case let .turnCompleted(conversationID, turnID):
            NotificationCenter.default.post(
                name: .lumiTurnCompleted,
                object: nil,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID,
                ]
            )
        case let .turnFinished(conversationID, turnID, reason):
            NotificationCenter.default.post(
                name: .lumiTurnFinished,
                object: nil,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID as Any,
                    "reason": reason.rawValue,
                ]
            )
        }
    }
}
