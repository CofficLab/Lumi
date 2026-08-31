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
        return await waitForCompletion(conversationID: conversationID)
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
              let toolCallID = suspension.toolCallID,
              let assistantMessage = messages.messages(for: conversationID).reversed().first(where: {
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
        if let pending = messages.messages(for: conversationID).last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
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
        return await waitForCompletion(conversationID: conversationID)
    }

    public func cancelTurn(in conversationID: UUID) {
        guard var runtime = runtimes[conversationID], let turnID = runtime.turnID else { return }
        let (updated, _) = TurnReducer.reduce(runtime, event: .cancel)
        runtime = updated
        runtime.task?.cancel()
        runtime.task = nil
        runtimes[conversationID] = runtime
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

    private func waitForCompletion(conversationID: UUID) async -> AgentLoopOutcome {
        await withCheckedContinuation { continuation in
            completionWaiters[conversationID, default: []].append(continuation)
        }
    }

    func finishTurn(conversationID: UUID, turnID: UUID, outcome: AgentLoopOutcome) {
        runtimes[conversationID]?.task = nil
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
                if let suspension = self.runtimes[conversationID]?.activeSuspension {
                    self.notify(.suspended(conversationID: conversationID, turnID: turnID, suspension: suspension))
                }
            }
            let waiters = self.completionWaiters.removeValue(forKey: conversationID) ?? []
            waiters.forEach { $0.resume(returning: outcome) }
        }
    }

    private func driveTurn(conversationID: UUID, turnID: UUID) async {
        guard let runtime = runtimes[conversationID] else {
            finishTurn(conversationID: conversationID, turnID: turnID, outcome: .failed("runtime not found"))
            return
        }
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
            let current = runtimes[conversationID] ?? TurnRuntime()
            switch result {
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
            case .failure(let reason):
                let (updated, outcome) = TurnReducer.reduce(current, event: .llmFailed(reason: reason))
                runtimes[conversationID] = updated
                finishTurn(conversationID: conversationID, turnID: currentTurnID, outcome: outcome ?? .failed(reason))
            }
        case .executingTools(_, _, let pending):
            if pending.isEmpty { finishTurn(conversationID: conversationID, turnID: turnID, outcome: .failed("empty tool batch")) }
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
