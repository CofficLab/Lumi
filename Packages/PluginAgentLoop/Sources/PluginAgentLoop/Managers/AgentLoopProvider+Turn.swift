import KitAgentTool
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import ProviderLifecycleHooks
import KitSuperLog

// MARK: - Public API

extension AgentLoopProvider {
    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)开始执行回合 - conversationID: \(conversationID)")
        }

        var runtime = runtimes[conversationID] ?? TurnRuntime()
        guard !runtime.isRunning else {
            return .failed("turn already running")
        }

        let turnID = UUID()
        let (updated, immediateOutcome) = TurnReducer.reduce(runtime, event: .startTurn(turnID: turnID))
        runtime = updated
        runtimes[conversationID] = runtime

        if let outcome = immediateOutcome {
            return outcome
        }

        await lifecycleHooks?.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )

        // 启动驱动任务
        let task = Task { @MainActor [weak self] in
            guard let self else { return AgentLoopOutcome.cancelled }
            return await self.driveTurn(conversationID: conversationID, turnID: turnID)
        }
        runtime.task = task
        runtimes[conversationID] = runtime

        let outcome = await task.value

        // 清理 task 引用
        runtimes[conversationID]?.task = nil
        await notifyTurnFinished(conversationID: conversationID, turnID: turnID, outcome: outcome)

        if Self.verbose {
            Self.logger.info("\(Self.t)回合执行完成 - conversationID: \(conversationID), outcome: \(String(describing: outcome))")
        }

        return outcome
    }

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)恢复回合 - conversationID: \(conversationID), suspensionID: \(request.suspensionID)")
        }

        guard var runtime = runtimes[conversationID] else {
            throw AgentLoopError.invalidResumeRequest
        }

        // 等待活跃任务完成（如果有）
        if let activeTask = runtime.task {
            _ = await activeTask.value
            runtime.task = nil
        }

        guard case .awaitingUser(let turnID, let assistantID, let pending, let suspension) = runtime.phase,
              suspension.suspensionID == request.suspensionID,
              let toolCallID = suspension.toolCallID else {
            throw AgentLoopError.invalidResumeRequest
        }

        // 验证 toolCall 存在
        guard let assistantMessage = messages.messages(for: conversationID)
            .reversed()
            .first(where: { $0.role == .assistant && $0.toolCalls?.contains(where: { $0.id == toolCallID }) == true }),
              let toolCall = assistantMessage.toolCalls?.first(where: { $0.id == toolCallID }) else {
            throw AgentLoopError.invalidResumeRequest
        }

        // 处理用户响应
        let result: MessageToolResult
        if suspension.kind == Self.toolApprovalSuspensionKind {
            if isToolApprovalGranted(request.answer) {
                result = await executeApprovedToolCall(toolCall, conversationID: conversationID)
            } else {
                result = MessageToolResult(
                    content: "User rejected the tool execution request.",
                    isError: true
                )
            }
        } else {
            result = MessageToolResult(content: request.answer)
        }

        // 更新消息
        messages.updateToolCallResult(result, toolCallID: toolCallID, assistantMessageID: assistantMessage.id, in: conversationID)
        if let pendingToolMessage = messages.messages(for: conversationID)
            .last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
            messages.updateMessage(
                id: pendingToolMessage.id,
                in: conversationID,
                content: suspension.kind == Self.toolApprovalSuspensionKind ? result.content : request.answer
            )
        }

        // 清理挂起
        runtime.pendingSuspensions.removeValue(forKey: toolCallID)

        // 派发事件
        let (updated, _) = TurnReducer.reduce(runtime, event: .toolCallCompleted(toolCallID: toolCallID, result: result))
        runtime = updated
        runtimes[conversationID] = runtime

        // 继续驱动
        let task = Task { @MainActor [weak self] in
            guard let self else { return AgentLoopOutcome.cancelled }
            return await self.driveTurn(conversationID: conversationID, turnID: turnID)
        }
        runtime.task = task
        runtimes[conversationID] = runtime

        let outcome = await task.value
        runtimes[conversationID]?.task = nil

        if Self.verbose {
            Self.logger.info("\(Self.t)回合恢复完成 - conversationID: \(conversationID)")
        }

        return outcome
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)取消回合 - conversationID: \(conversationID)")
        }

        guard var runtime = runtimes[conversationID] else { return }

        let (updated, _) = TurnReducer.reduce(runtime, event: .cancel)
        runtime = updated
        runtimes[conversationID] = runtime

        runtime.task?.cancel()
        runtime.task = nil
        runtimes[conversationID] = runtime
    }
}

// MARK: - Drive Loop

extension AgentLoopProvider {
    /// 驱动状态机：根据当前 phase 执行异步操作，将结果作为事件反馈给 reducer，循环直到终态。
    private func driveTurn(conversationID: UUID, turnID: UUID) async -> AgentLoopOutcome {
        while true {
            guard let runtime = runtimes[conversationID] else {
                return .failed("runtime not found")
            }

            // 检查取消
            if runtime.cancelRequested && !runtime.phase.isTerminal {
                let (updated, outcome) = TurnReducer.reduce(runtime, event: .cancel)
                runtimes[conversationID] = updated
                if let o = outcome { return o }
            }

            switch runtime.phase {
            case .idle, .completed, .failed, .cancelled:
                // 终态或空闲，不应到达这里
                return extractOutcome(from: runtime.phase)

            case .requestingLLM(let tid):
                let result = await performLLMRequest(conversationID: conversationID, turnID: tid)
                var rt = runtimes[conversationID] ?? TurnRuntime()
                switch result {
                case .success(let response, let assistantID):
                    let (updated, outcome) = TurnReducer.reduce(rt, event: .llmResponded(response: response, assistantMessageID: assistantID))
                    rt = updated
                    runtimes[conversationID] = rt
                    if let o = outcome { return o }
                    // 继续循环，下一个 phase 是 executingTools 或 completed

                case .failure(let reason):
                    let (updated, outcome) = TurnReducer.reduce(rt, event: .llmFailed(reason: reason))
                    runtimes[conversationID] = updated
                    if let o = outcome { return o }
                    return .failed(reason)
                }

            case .executingTools(let tid, let assistantID, let pending):
                guard !pending.isEmpty else {
                    // 不应到达这里（reducer 应在 pending 为空时转到 requestingLLM）
                    let (updated, _) = TurnReducer.reduce(runtime, event: .llmResponded(
                        response: LLMResponse(content: "", model: nil, toolCalls: nil),
                        assistantMessageID: assistantID
                    ))
                    runtimes[conversationID] = updated
                    continue
                }

                // 批量执行所有工具
                let batchResult = await performToolBatch(pending, conversationID: conversationID, turnID: tid)
                var rt = runtimes[conversationID] ?? TurnRuntime()

                switch batchResult {
                case .allCompleted(let results):
                    // 所有工具执行完成，插入结果消息并派发事件
                    for (toolCallID, result) in results {
                        insertToolResultMessage(result, toolCallID: toolCallID, conversationID: conversationID, turnID: tid)
                        let (updated, outcome) = TurnReducer.reduce(rt, event: .toolCallCompleted(toolCallID: toolCallID, result: result))
                        rt = updated
                        runtimes[conversationID] = rt
                        if let o = outcome { return o }
                    }

                case .suspended(let suspension, let completedResults):
                    // 先插入已完成的结果
                    for (toolCallID, result) in completedResults {
                        insertToolResultMessage(result, toolCallID: toolCallID, conversationID: conversationID, turnID: tid)
                        let (updated, _) = TurnReducer.reduce(rt, event: .toolCallCompleted(toolCallID: toolCallID, result: result))
                        rt = updated
                        runtimes[conversationID] = rt
                    }
                    // 然后派发挂起事件
                    let event: TurnEvent
                    if suspension.kind == Self.toolApprovalSuspensionKind {
                        event = .toolNeedsApproval(toolCallID: suspension.toolCallID ?? "", suspension: suspension)
                    } else {
                        event = .toolNeedsUserInput(toolCallID: suspension.toolCallID ?? "", suspension: suspension)
                    }
                    let (updated, outcome) = TurnReducer.reduce(rt, event: event)
                    rt = updated
                    runtimes[conversationID] = rt
                    if let o = outcome { return o }
                }

            case .awaitingUser:
                // 挂起状态，返回 suspended outcome
                return .suspended(runtime.activeSuspension?.suspensionID ?? "unknown")
            }
        }
    }

    private func extractOutcome(from phase: TurnPhase) -> AgentLoopOutcome {
        switch phase {
        case .idle: return .failed("unexpected idle state")
        case .completed: return .completed
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        case .requestingLLM, .executingTools, .awaitingUser:
            return .failed("unexpected non-terminal state")
        }
    }
}
