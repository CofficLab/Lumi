import Foundation

/// 聊天发送与回合驱动控制器
///
/// **职责**：队列调度 + 任务生命周期管理。
///
/// 每个窗口拥有独立的 SendController 实例，通过 WindowContainer 直接访问窗口级 VM。
/// 不再通过 RootContainer 的 activeWindowContainer 代理，避免多窗口状态竞争。
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = 0

    private let windowContainer: WindowContainer
    private let global: RootContainer
    private let agentTurnService: AgentTurnService
    private var activeSendTasksByConversation: [UUID: Task<Void, Never>] = [:]
    private var pendingTransientSystemPromptsByConversation: [UUID: [String]] = [:]

    init(container: WindowContainer, global: RootContainer) {
        self.windowContainer = container
        self.global = global

        // 组装 AgentTurnService 的依赖（使用窗口级 VM）
        let llmRequester = LLMRequester(
            llmService: global.llmService,
            agentSessionConfig: global.agentSessionConfig,
            toolService: global.toolService,
            pluginVM: global.pluginVM,
            statusVM: windowContainer.conversationSendStatusVM,
            projectVM: windowContainer.projectVM
        )
        let toolCallExecutor = ToolCallExecutor(
            toolExecutionService: global.toolExecutionService,
            toolService: global.toolService,
            projectVM: windowContainer.projectVM,
            permissionRequestVM: windowContainer.permissionRequestVM,
            conversationSendStatusVM: windowContainer.conversationSendStatusVM,
            conversationVM: windowContainer.conversationVM
        )
        let turnFinalizer = TurnFinalizer(
            conversationVM: windowContainer.conversationVM,
            conversationSendStatusVM: windowContainer.conversationSendStatusVM,
            messageQueueVM: windowContainer.messageQueueVM
        )
        self.agentTurnService = AgentTurnService(
            llmRequester: llmRequester,
            toolCallExecutor: toolCallExecutor,
            turnFinalizer: turnFinalizer,
            chatHistoryService: global.chatHistoryService,
            conversationVM: windowContainer.conversationVM,
            messageQueueVM: windowContainer.messageQueueVM
        )
    }

    // MARK: - 队列调度

    /// 尝试从队列中出队一条"可处理"的消息并开始发送。
    func attemptBeginNextQueuedSend() async {
        guard let message = windowContainer.messageQueueVM.dequeueNextEligibleMessage() else {
            return
        }
        let conversationId = message.conversationId

        // 如果该会话已有活跃任务，将消息状态改回 pending，避免卡住
        guard activeSendTasksByConversation[conversationId] == nil else {
            windowContainer.messageQueueVM.requeueMessage(message)
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

        if windowContainer.permissionRequestVM.pendingToolPermissionSession?.conversationId == conversationId {
            windowContainer.permissionRequestVM.setPendingPermissionRequest(nil)
            windowContainer.permissionRequestVM.setPendingToolPermissionSession(nil)
        }

        windowContainer.conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        windowContainer.messageQueueVM.finishProcessing(for: conversationId)
        windowContainer.conversationSendStatusVM.clearStatus(conversationId: conversationId)

        guard shouldPersistCancelMessage else { return }
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: "用户主动取消了对话")
        windowContainer.conversationVM.saveMessage(systemMessage, to: conversationId)
    }

    /// 取消当前窗口内所有发送任务。窗口关闭时调用，不落库“用户取消”消息。
    func cancelAllSendsForTeardown() {
        for task in activeSendTasksByConversation.values {
            task.cancel()
        }
        activeSendTasksByConversation.removeAll()
        pendingTransientSystemPromptsByConversation.removeAll()

        windowContainer.permissionRequestVM.clearPending()
        windowContainer.messageQueueVM.clearAll()
        windowContainer.conversationSendStatusVM.clearAll()
    }

    // MARK: - 发送入口

    private func beginSendFromQueue(conversationId: UUID, message: ChatMessage) async {
        if Self.verbose >= 1 {
            AppLogger.core.info("\(Self.t) [\(conversationId)] 启动一次发送链路：\n\(message.content.max(count: 200))")
        }

        windowContainer.conversationVM.saveMessage(message, to: conversationId)

        let ctx = SendMessageContext(
            conversationId: conversationId,
            message: message,
            chatHistoryService: global.chatHistoryService,
            agentSessionConfig: global.agentSessionConfig,
            projectVM: windowContainer.projectVM,
            recentProjectsVM: global.recentProjectsVM,
            currentFileURL: windowContainer.editorVM.service.currentFileURL
        )
        ctx.abortTurn = { [weak self] in
            self?.windowContainer.conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "检测到异常，已终止"
            )
            self?.windowContainer.messageQueueVM.finishProcessing(for: conversationId)
            self?.windowContainer.conversationSendStatusVM.clearStatus(conversationId: conversationId)
        }

        let pipeline = SendPipeline(middlewares: global.pluginVM.getSuperSendMiddlewares())
        await pipeline.run(ctx: ctx) { _ in
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 发送管道完成")
            }
        }
        pendingTransientSystemPromptsByConversation[conversationId] = ctx.transientSystemPrompts

        let systemPrompts = consumeTransientSystemPrompts(for: conversationId)
        await agentTurnService.run(conversationId: conversationId, additionalSystemPrompts: systemPrompts)
    }

    // MARK: - 权限恢复入口

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
