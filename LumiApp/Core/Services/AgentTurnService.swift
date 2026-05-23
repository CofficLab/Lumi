import Foundation
import AgentToolKit

/// Agent 回合服务
///
/// 驱动一轮完整的 Agent 循环：
///
/// ```
/// 用户消息 → 请求 LLM → 解析工具调用 → 执行工具 → 再请求 LLM → ... → 结束
/// ```
///
/// 这是整个对话引擎的**核心状态机**。它不关心队列调度、UI 绑定等外部细节，
/// 只专注于「读消息 → 判断下一步 → 执行 → 重复」这个循环。
///
/// ## 设计原则
///
/// - **单一入口**：`run()` 是唯一的公开方法
/// - **职责委托**：LLM 请求 → `LLMRequester`，工具执行 → `ToolCallExecutor`，收尾 → `TurnFinalizer`
@MainActor
final class AgentTurnService: SuperLog {
    nonisolated static let emoji = "🔄"

    private let llmRequester: LLMRequester
    private let toolCallExecutor: ToolCallExecutor
    private let turnFinalizer: TurnFinalizer
    private let chatHistoryService: ChatHistoryService
    private let conversationVM: WindowConversationVM
    private let messageQueueVM: WindowMessageQueueVM

    init(
        llmRequester: LLMRequester,
        toolCallExecutor: ToolCallExecutor,
        turnFinalizer: TurnFinalizer,
        chatHistoryService: ChatHistoryService,
        conversationVM: WindowConversationVM,
        messageQueueVM: WindowMessageQueueVM
    ) {
        self.llmRequester = llmRequester
        self.toolCallExecutor = toolCallExecutor
        self.turnFinalizer = turnFinalizer
        self.chatHistoryService = chatHistoryService
        self.conversationVM = conversationVM
        self.messageQueueVM = messageQueueVM
    }

    // MARK: - 公开接口

    /// 运行一轮完整的 Agent 循环。
    ///
    /// 从数据库中读取消息历史，根据最后一条消息的角色决定下一步：
    /// - `user` / 遗留 `tool`：向 LLM 发起流式请求
    /// - `assistant`（含未完成工具调用）：执行工具并将结果写回 ToolCall
    /// - `assistant`（工具调用均已有结果）：向 LLM 发起流式请求
    /// - `assistant`（无工具调用）：对话回合结束
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - additionalSystemPrompts: 临时系统提示词（仅在首轮请求中使用）
    func run(conversationId: UUID, additionalSystemPrompts: [String] = []) async {
        // 消费掉临时提示词（仅第一轮使用）
        var remainingSystemPrompts = additionalSystemPrompts

        // ── Agent 循环 ──────────────────────────────────
        while true {
            // 检查是否仍在处理中
            guard messageQueueVM.isProcessing(for: conversationId) else { return }

            // 加载最新消息
            let messages = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
            guard !messages.isEmpty else {
                AppLogger.core.error("\(Self.t) [\(conversationId)] 无消息")
                return
            }

            // 找到最后一条可驱动消息（跳过 system/status 消息）
            guard let last = messages.last(where: { $0.role != .system && $0.role != .status }) else {
                return
            }

            switch last.role {
            case .user, .tool:
                guard await requestLLM(
                    conversationId: conversationId,
                    storageMessages: messages,
                    remainingSystemPrompts: &remainingSystemPrompts
                ) else { return }

            case .assistant:
                if last.hasToolCalls {
                    if last.toolCalls?.contains(where: { $0.result == nil }) == true {
                        if await toolCallExecutor.presentPermissionIfNeeded(
                            assistantMessage: last,
                            conversationId: conversationId
                        ) {
                            return
                        }

                        let hadUserRejection = await toolCallExecutor.executeAll(
                            assistantMessage: last,
                            conversationId: conversationId
                        )

                        if hadUserRejection {
                            turnFinalizer.finishTurnByUserRejection(conversationId: conversationId)
                            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
                            return
                        }

                        continue
                    }

                    guard await requestLLM(
                        conversationId: conversationId,
                        storageMessages: messages,
                        remainingSystemPrompts: &remainingSystemPrompts
                    ) else { return }
                } else {
                    turnFinalizer.finishTurn(conversationId: conversationId)
                    NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
                    return
                }

            case .system, .status, .error, .unknown:
                return
            }
        }
    }

    /// - Returns: 是否应继续 Agent 循环
    private func requestLLM(
        conversationId: UUID,
        storageMessages: [ChatMessage],
        remainingSystemPrompts: inout [String]
    ) async -> Bool {
        let llmMessages = chatHistoryService.expandMessagesForLLM(storageMessages)
        let result = await llmRequester.request(
            conversationId: conversationId,
            messages: llmMessages,
            additionalSystemPrompts: remainingSystemPrompts
        )
        remainingSystemPrompts = []

        switch result {
        case let .success(assistantMessage):
            let processed = toolCallExecutor.evaluatePermissions(for: assistantMessage)
            conversationVM.saveMessage(processed, to: conversationId)
            return true

        case .cancelled:
            turnFinalizer.finishTurnByCancellation(conversationId: conversationId)
            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
            return false

        case let .failed(error):
            let providerId = llmRequester.currentProviderId(for: conversationId)
            turnFinalizer.finishTurnWithError(error, conversationId: conversationId, providerId: providerId)
            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
            return false
        }
    }
}

// MARK: - LLMRequester 便捷扩展

extension LLMRequester {
    /// 获取当前会话的 providerId（供 TurnFinalizer 使用）
    func currentProviderId(for conversationId: UUID) -> String? {
        conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: agentSessionConfig
        ).providerId
    }
}
