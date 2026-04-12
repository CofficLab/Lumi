import Foundation
import MagicKit

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
    private let conversationVM: ConversationVM
    private let messageQueueVM: MessageQueueVM

    init(
        llmRequester: LLMRequester,
        toolCallExecutor: ToolCallExecutor,
        turnFinalizer: TurnFinalizer,
        chatHistoryService: ChatHistoryService,
        conversationVM: ConversationVM,
        messageQueueVM: MessageQueueVM
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
    /// - `user` / `tool`：向 LLM 发起流式请求
    /// - `assistant`（含工具调用）：执行工具
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
                // ── 向 LLM 请求 ──
                let result = await llmRequester.request(
                    conversationId: conversationId,
                    messages: messages,
                    additionalSystemPrompts: remainingSystemPrompts
                )
                // 临时提示词只在第一轮使用
                remainingSystemPrompts = []

                switch result {
                case let .success(assistantMessage):
                    let processed = toolCallExecutor.evaluatePermissions(for: assistantMessage)
                    conversationVM.saveMessage(processed, to: conversationId)
                    // 继续循环，下一轮会根据 assistantMessage 是否有 toolCalls 决定下一步

                case .cancelled:
                    turnFinalizer.finishTurnByCancellation(conversationId: conversationId)
                    return

                case let .failed(error):
                    let providerId = llmRequester.currentProviderId(for: conversationId)
                    turnFinalizer.finishTurnWithError(error, conversationId: conversationId, providerId: providerId)
                    return
                }

            case .assistant:
                if last.hasToolCalls {
                    // ── 执行工具 ──
                    // 先检查是否需要弹窗授权
                    if await toolCallExecutor.presentPermissionIfNeeded(assistantMessage: last, conversationId: conversationId) {
                        return // 暂停循环，等待用户授权后恢复
                    }

                    // 执行所有工具调用
                    let hadUserRejection = await toolCallExecutor.executeAll(
                        assistantMessage: last,
                        conversationId: conversationId
                    )

                    if hadUserRejection {
                        turnFinalizer.finishTurnByUserRejection(conversationId: conversationId)
                        return
                    }

                    // 工具结果已落库，继续循环 → 下一轮会读到 tool 消息，再次请求 LLM
                } else {
                    // 助手消息没有工具调用 → 对话回合正常结束
                    turnFinalizer.finishTurn(conversationId: conversationId)
                    return
                }

            case .system, .status, .error, .unknown:
                return
            }
        }
    }
}

// MARK: - LLMRequester 便捷扩展

extension LLMRequester {
    /// 获取当前会话的 providerId（供 TurnFinalizer 使用）
    func currentProviderId(for conversationId: UUID) -> String? {
        agentSessionConfig.getCurrentConfig().providerId
    }
}
