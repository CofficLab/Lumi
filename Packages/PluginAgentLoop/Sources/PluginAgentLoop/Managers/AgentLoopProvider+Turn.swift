import Foundation
import KitLLM
import ProviderAgentLoop
import ProviderMessage
import ProviderLifecycleHooks

extension AgentLoopManager {
    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        var runtime = runtimes[conversationID] ?? TurnRuntime()
        guard !runtime.isRunning else { return .failed("turn already running") }
        let turnID = UUID()
        let (updated, immediateOutcome) = TurnReducer.reduce(runtime, event: .startTurn(turnID: turnID))
        runtime = updated
        runtimes[conversationID] = runtime
        if let immediateOutcome { return immediateOutcome }
        await lifecycleHooks?.notifyTurnStarted(TurnLifecycleContext(conversationID: conversationID, turnID: turnID))
        notify(.started(conversationID: conversationID, turnID: turnID))
        launchAdvance(conversationID: conversationID, turnID: turnID)
        return await waitForCompletion(conversationID: conversationID, turnID: turnID)
    }

    public func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        guard var runtime = runtimes[conversationID] else { throw AgentLoopError.invalidResumeRequest }
        guard resumingConversations.insert(conversationID).inserted else {
            throw AgentLoopError.invalidResumeRequest
        }
        defer { resumingConversations.remove(conversationID) }
        if let task = runtime.task { await task.value }
        guard case .awaitingUser(let turnID, _, let pendingToolCalls, let suspension) = runtime.phase,
              suspension.suspensionID == request.suspensionID,
              let toolCallID = suspension.toolCallID else {
            throw AgentLoopError.invalidResumeRequest
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard let assistantMessage = snapshot.reversed().first(where: {
                  $0.role == .assistant && $0.toolCalls?.contains(where: { $0.id == toolCallID }) == true
              }),
              let toolCall = assistantMessage.toolCalls?.first(where: { $0.id == toolCallID }) else {
            throw AgentLoopError.invalidResumeRequest
        }
        let result = convertResult(await toolManager.resolveUserResponse(
            request.answer,
            for: AgentLoopToolCall(id: toolCall.id, name: toolCall.name, arguments: toolCall.arguments),
            conversationID: conversationID,
            turnID: turnID
        ))
        messages.updateToolCallResult(result, toolCallID: toolCallID, assistantMessageID: assistantMessage.id, in: conversationID)
        if let pending = (await messages.messagesSnapshot(in: conversationID)).last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
            messages.updateMessage(id: pending.id, in: conversationID, content: result.content)
        }
        runtime.pendingSuspensions.removeValue(forKey: toolCallID)
        // Reducer 的 toolCallCompleted 事件只接受 executingTools；恢复时把
        // 当前已挂起调用临时放回待执行集合，再由 reducer 原子移除它。
        runtime.phase = .executingTools(
            turnID: turnID,
            assistantMessageID: assistantMessage.id,
            pendingToolCalls: [toolCall] + pendingToolCalls
        )
        runtime.completionDelivered = false
        let (next, outcome) = TurnReducer.reduce(runtime, event: .toolCallCompleted(toolCallID: toolCallID, result: result))
        runtimes[conversationID] = next
        if let outcome { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome); return outcome }
        if case .executingTools(let nextTurnID, let assistantMessageID, let remaining) = next.phase,
           !remaining.isEmpty {
            // 用户响应只完成当前挂起调用。剩余调用重新交给 ToolManager，
            // AgentLoop 不直接执行工具，也不重新计算授权策略。
            notify(.toolCallsReceived(
                conversationID: conversationID,
                turnID: nextTurnID,
                assistantMessageID: assistantMessageID,
                toolCalls: remaining
            ))
        } else {
            launchAdvance(conversationID: conversationID, turnID: turnID)
        }
        // 只保护 resolveUserResponse 到状态转换这一小段临界区；恢复后的
        // 回合若再次 ask_user，新的消息仍应能够跳过新的挂起点。
        resumingConversations.remove(conversationID)
        return await waitForCompletion(conversationID: conversationID, turnID: turnID)
    }

    public func cancelTurn(in conversationID: UUID) {
        guard var runtime = runtimes[conversationID], let turnID = runtime.turnID else { return }
        guard runtime.isRunning else { return }
        let (updated, _) = TurnReducer.reduce(runtime, event: .cancel)
        runtime = updated
        runtime.task?.cancel()
        runtime.task = nil
        // 先写入 cancelled 状态，再取消底层 Job。cancelJobs 可能在同一个
        // MainActor 调用栈内同步发布 cancelled 事件，提前写入可避免该事件
        // 被误当成普通完成而重新启动 LLM。
        runtimes[conversationID] = runtime
        toolManager.cancelJobs(forTurnID: turnID)
        finishTurn(conversationID: conversationID, turnID: turnID, outcome: .cancelled)
    }
}

extension AgentLoopManager {
    func launchAdvance(conversationID: UUID, turnID: UUID) {
        guard var runtime = runtimes[conversationID] else {
            Self.logger.error("\(Self.t)无法推进 AgentLoop：找不到会话运行时 conversation=\(conversationID.uuidString.prefix(8))")
            return
        }
        guard runtime.task == nil else {
            Self.logger.error("\(Self.t)无法推进 AgentLoop：会话仍有运行中的任务 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
            return
        }
        if Self.verbose { Self.logger.info("\(Self.t)launchAdvance accepted conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), phase=\(String(describing: runtime.phase))") }
        runtime.task = Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.t)无法推进 AgentLoop：AgentLoopManager 已释放 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
                return
            }
            await self.driveTurn(conversationID: conversationID, turnID: turnID)
        }
        runtimes[conversationID] = runtime
        if Self.verbose { Self.logger.info("\(Self.t)launchAdvance task installed conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))") }
    }

    private func waitForCompletion(conversationID: UUID, turnID: UUID) async -> AgentLoopOutcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if let runtime = runtimes[conversationID],
                   runtime.lastTurnID == turnID,
                   let outcome = finishableOutcome(for: runtime.phase) {
                    continuation.resume(returning: outcome)
                } else if Task.isCancelled {
                    continuation.resume(returning: .cancelled)
                } else {
                    completionWaiters[conversationID, default: []].append(
                        CompletionWaiter(turnID: turnID, continuation: continuation)
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self,
                      self.runtimes[conversationID]?.lastTurnID == turnID else { return }
                self.cancelTurn(in: conversationID)
            }
        }
    }

    func finishTurn(conversationID: UUID, turnID: UUID, outcome: AgentLoopOutcome) {
        guard var runtime = runtimes[conversationID],
              runtime.lastTurnID == turnID,
              finishableOutcome(for: runtime.phase) == outcome,
              !runtime.completionDelivered else {
            if Self.verbose {
                Self.logger.debug(
                    "\(Self.t)忽略重复或过期的 finishTurn conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))"
                )
            }
            return
        }
        runtime.completionDelivered = true
        runtime.task = nil
        runtimes[conversationID] = runtime
        let suspendedState = runtime.activeSuspension
        let waiters = completionWaiters[conversationID] ?? []
        let matchingWaiters = waiters.filter { $0.turnID == turnID }
        let remainingWaiters = waiters.filter { $0.turnID != turnID }
        if remainingWaiters.isEmpty {
            completionWaiters.removeValue(forKey: conversationID)
        } else {
            completionWaiters[conversationID] = remainingWaiters
        }
        Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.t)无法完成 AgentLoop 回合：AgentLoopManager 已释放 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
                return
            }
            await self.notifyTurnFinished(conversationID: conversationID, turnID: turnID, outcome: outcome)
            switch outcome {
            case .completed: self.notify(.completed(conversationID: conversationID, turnID: turnID))
            case .failed(let reason): self.notify(.failed(conversationID: conversationID, turnID: turnID, reason: reason))
            case .cancelled: self.notify(.cancelled(conversationID: conversationID, turnID: turnID))
            case .suspended:
                if let suspension = suspendedState {
                    self.notify(.suspended(conversationID: conversationID, turnID: turnID, suspension: suspension))
                }
            }
            matchingWaiters.forEach { $0.continuation.resume(returning: outcome) }
        }
    }

    private func finishableOutcome(for phase: TurnPhase) -> AgentLoopOutcome? {
        switch phase {
        case .completed: return .completed
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        case .awaitingUser: return .suspended("awaiting user response")
        default: return nil
        }
    }

    private func driveTurn(conversationID: UUID, turnID: UUID) async {
        guard let runtime = runtimes[conversationID] else {
            finishTurn(conversationID: conversationID, turnID: turnID, outcome: .failed("runtime not found"))
            return
        }
        guard runtime.lastTurnID == turnID, !Task.isCancelled else { return }
        if runtime.cancelRequested && !runtime.phase.isTerminal {
            let (updated, outcome) = TurnReducer.reduce(runtime, event: .cancel)
            runtimes[conversationID] = updated
            if let outcome { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome) }
            return
        }
        switch runtime.phase {
        case .idle, .completed, .failed, .cancelled:
            finishTurn(conversationID: conversationID, turnID: turnID, outcome: extractOutcome(from: runtime.phase))
        case .requestingLLM(let currentTurnID):
            let result = await performLLMRequest(conversationID: conversationID, turnID: currentTurnID)
            guard !Task.isCancelled,
                  let activeRuntime = runtimes[conversationID],
                  activeRuntime.lastTurnID == currentTurnID,
                  activeRuntime.phase == .requestingLLM(turnID: currentTurnID),
                  !activeRuntime.cancelRequested else {
                // Provider 可能忽略 Task cancellation；此处仍必须丢弃迟到响应。
                return
            }
            let current = runtimes[conversationID] ?? TurnRuntime()
            switch result {
            case .cancelled:
                return
            case .success(let response, let assistantID):
                let (updated, outcome) = TurnReducer.reduce(current, event: .llmResponded(response: response, assistantMessageID: assistantID))
                runtimes[conversationID] = updated
                if let outcome {
                    finishTurn(conversationID: conversationID, turnID: currentTurnID, outcome: outcome)
                } else {
                    // 当前 LLM 单步已完成。先释放 task，再发布工具事件，
                    // 确保 batchCompleted 到达时可以启动下一步 LLM。
                    runtimes[conversationID]?.task = nil
                    notifyLLMResponse(
                        conversationID: conversationID,
                        turnID: currentTurnID,
                        assistantMessageID: assistantID,
                        toolCalls: response.toolCalls?.map { MessageToolCall(
                            id: $0.id,
                            name: $0.name,
                            arguments: $0.arguments
                        ) } ?? []
                    )
                }
            case .failure(let error, let recoverable):
                let reason = String(describing: error)
                let event: TurnEvent = recoverable
                    ? .llmRetryableFailure(reason: reason)
                    : .llmFailed(reason: reason)
                let (updated, outcome) = TurnReducer.reduce(current, event: event)
                runtimes[conversationID] = updated
                if let outcome {
                    await appendError(in: conversationID, error: error, turnID: currentTurnID)
                    finishTurn(conversationID: conversationID, turnID: currentTurnID, outcome: outcome)
                } else {
                    // 当前任务仍在进行中；释放本轮 Task 后再启动下一次 LLM 请求。
                    runtimes[conversationID]?.task = nil
                    launchAdvance(conversationID: conversationID, turnID: currentTurnID)
                }
            }
        case .executingTools(_, _, let pending):
            if pending.isEmpty { finishTurn(conversationID: conversationID, turnID: turnID, outcome: .failed("empty tool batch")) }
        case .waitingForToolJobs:
            // Job 运行由 ToolExecutionManager 驱动；等待期间不保留一个长期 Agent Task。
            break
        case .awaitingUser:
            finishTurn(conversationID: conversationID, turnID: turnID, outcome: .suspended(runtime.activeSuspension?.suspensionID ?? "unknown"))
        }
    }

    private func extractOutcome(from phase: TurnPhase) -> AgentLoopOutcome {
        switch phase {
        case .completed: return .completed
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        default: return .failed("unexpected non-terminal state")
        }
    }
}
