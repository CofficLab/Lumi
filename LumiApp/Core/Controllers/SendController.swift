import Foundation
import MagicKit

/// 聊天发送与回合驱动控制器
///
/// **职责**：队列调度 + 任务生命周期管理。
///
/// 这个控制器是一个"薄壳"，不包含任何 Agent 循环逻辑、重试逻辑或工具执行逻辑。
/// 所有核心逻辑委托给 `AgentTurnService`。
///
/// ## 架构
///
/// ```
/// 用户点击发送
///     ↓
/// SendController（队列调度 + Task 管理）
///     ↓
/// AgentTurnService（Agent 循环：LLM → 工具 → LLM → ...）
///   ├── LLMRequester（流式请求 + 重试）
///   ├── ToolCallExecutor（工具执行 + 权限 + 进度）
///   └── TurnFinalizer（收尾）
/// ```
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 0

    private let container: RootViewContainer
    private let agentTurnService: AgentTurnService
    private var activeSendTasksByConversation: [UUID: Task<Void, Never>] = [:]
    private var pendingTransientSystemPromptsByConversation: [UUID: [String]] = [:]

    init(container: RootViewContainer) {
        self.container = container

        // 组装 AgentTurnService 的依赖
        let llmRequester = LLMRequester(
            llmService: container.llmService,
            agentSessionConfig: container.agentSessionConfig,
            toolService: container.toolService,
            pluginVM: container.pluginVM,
            statusVM: container.conversationSendStatusVM
        )
        let toolCallExecutor = ToolCallExecutor(
            toolExecutionService: container.toolExecutionService,
            toolService: container.toolService,
            projectVM: container.projectVM,
            permissionRequestVM: container.permissionRequestVM,
            conversationSendStatusVM: container.conversationSendStatusVM,
            conversationVM: container.conversationVM
        )
        let turnFinalizer = TurnFinalizer(
            conversationVM: container.conversationVM,
            conversationSendStatusVM: container.conversationSendStatusVM,
            messageQueueVM: container.messageQueueVM
        )
        self.agentTurnService = AgentTurnService(
            llmRequester: llmRequester,
            toolCallExecutor: toolCallExecutor,
            turnFinalizer: turnFinalizer,
            chatHistoryService: container.chatHistoryService,
            conversationVM: container.conversationVM,
            messageQueueVM: container.messageQueueVM
        )
    }

    // MARK: - 队列调度

    /// 尝试从队列中出队一条"可处理"的消息并开始发送。
    func attemptBeginNextQueuedSend() async {
        guard let message = container.messageQueueVM.dequeueNextEligibleMessage() else { return }
        let conversationId = message.conversationId

        // 如果该会话已有活跃任务，将消息状态改回 pending，避免卡住
        guard activeSendTasksByConversation[conversationId] == nil else {
            container.messageQueueVM.requeueMessage(message)
            return
        }

        activeSendTasksByConversation[conversationId] = Task { [weak self] in
            guard let self = self else { return }
            await self.beginSendFromQueue(conversationId: conversationId, message: message)
            await MainActor.run {
                self.activeSendTasksByConversation[conversationId] = nil
            }
        }
    }

    /// 取消某个会话当前发送任务，并清理处理中状态。
    func cancelSend(conversationId: UUID) {
        let shouldPersistCancelMessage = activeSendTasksByConversation[conversationId] != nil
        activeSendTasksByConversation[conversationId]?.cancel()
        activeSendTasksByConversation[conversationId] = nil

        if container.permissionRequestVM.pendingToolPermissionSession?.conversationId == conversationId {
            container.permissionRequestVM.setPendingPermissionRequest(nil)
            container.permissionRequestVM.setPendingToolPermissionSession(nil)
        }

        container.conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        container.messageQueueVM.finishProcessing(for: conversationId)
        container.conversationSendStatusVM.clearStatus(conversationId: conversationId)

        // 用户主动取消后，补一条系统消息落库（不参与 LLM 上下文）。
        guard shouldPersistCancelMessage else { return }
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: "用户主动取消了对话")
        container.conversationVM.saveMessage(systemMessage, to: conversationId)
    }

    // MARK: - 发送入口

    /// 从队列入口启动一次发送链路：投影 UI、落库、运行发送中间件，然后委托给 AgentTurnService。
    private func beginSendFromQueue(conversationId: UUID, message: ChatMessage) async {
        if Self.verbose >= 1 {
            AppLogger.core.info("\(Self.t) [\(conversationId)] 启动一次发送链路：\n\(message.content.max(200))")
        }

        if container.conversationVM.selectedConversationId == conversationId {
            container.messagePendingVM.appendMessage(message)
        }

        container.conversationVM.saveMessage(message, to: conversationId)

        // 创建发送上下文
        let ctx = SendMessageContext(
            conversationId: conversationId,
            message: message,
            chatHistoryService: container.chatHistoryService,
            agentSessionConfig: container.agentSessionConfig,
            projectVM: container.projectVM
        )
        ctx.abortTurn = { [weak self] in
            self?.container.conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "检测到异常，已终止"
            )
            self?.container.messageQueueVM.finishProcessing(for: conversationId)
            self?.container.conversationSendStatusVM.clearStatus(conversationId: conversationId)
        }

        let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
        await pipeline.run(ctx: ctx) { _ in
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 发送管道完成")
            }
        }
        pendingTransientSystemPromptsByConversation[conversationId] = ctx.transientSystemPrompts

        // 委托给 AgentTurnService 运行完整的 Agent 循环
        let systemPrompts = consumeTransientSystemPrompts(for: conversationId)
        await agentTurnService.run(conversationId: conversationId, additionalSystemPrompts: systemPrompts)
    }

    // MARK: - 权限恢复入口

    /// 用户授权工具后，恢复 Agent 循环。
    ///
    /// 由 UI 层（PermissionHandlingVM）在用户点击"允许"后调用。
    func resumeAfterPermissionGranted(conversationId: UUID) async {
        await agentTurnService.run(conversationId: conversationId)
    }

    // MARK: - 私有辅助

    private func consumeTransientSystemPrompts(for conversationId: UUID) -> [String] {
        let prompts = pendingTransientSystemPromptsByConversation[conversationId] ?? []
        pendingTransientSystemPromptsByConversation[conversationId] = nil
        return prompts
    }
}
