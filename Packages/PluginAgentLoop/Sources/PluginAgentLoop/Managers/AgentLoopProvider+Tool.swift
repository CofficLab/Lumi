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

// MARK: - LLM Request

extension AgentLoopManager {
    /// 接收 ToolManager 的批量完成事件，推进当前回合状态机。
    func handleToolManagerEvent(_ event: ToolManagerEvent) {
        if case let .authorizedCompleted(conversationID, eventTurnID, toolCall, result) = event {
            handleAuthorizedToolCompletion(
                conversationID: conversationID,
                eventTurnID: eventTurnID,
                toolCall: toolCall,
                result: result
            )
            return
        }
        guard case .batchCompleted(let conversationID, let eventTurnID, let toolCalls, let results) = event else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)handle batch begin conversation=\(conversationID.uuidString.prefix(8)), turn=\(eventTurnID?.uuidString.prefix(8) ?? "nil"), calls=\(toolCalls.map { $0.id }), results=\(results.count)")
        }
        guard let firstToolCall = toolCalls.first,
              prepareRuntimeForToolResult(
                  conversationID: conversationID,
                  eventTurnID: eventTurnID,
                  toolCall: firstToolCall
              ),
              var runtime = runtimes[conversationID] else {
            if Self.verbose { Self.logger.error("\(Self.t)忽略工具批次结果：找不到会话运行时 conversation=\(conversationID.uuidString.prefix(8))") }
            return
        }
        guard case .executingTools(let turnID, let assistantMessageID, let pending) = runtime.phase else {
            if Self.verbose { Self.logger.error("\(Self.t)忽略工具批次结果：当前状态不是 executingTools，conversation=\(conversationID.uuidString.prefix(8)), phase=\(String(describing: runtime.phase))") }
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)handle batch state accepted phase=executingTools, pending=\(pending.map(\.id)), assistant=\(assistantMessageID.uuidString.prefix(8))")
        }
        guard eventTurnID == nil || eventTurnID == turnID else {
            if Self.verbose { Self.logger.error("\(Self.t)忽略工具批次结果：turnID 不匹配，conversation=\(conversationID.uuidString.prefix(8))") }
            return
        }

        var suspension: AgentLoopSuspension?
        for (call, batchResult) in zip(toolCalls, results) {
            if Self.verbose {
                Self.logger.info("\(Self.t)handle batch result begin id=\(call.id), name=\(call.name)")
            }
            guard pending.contains(where: { $0.id == call.id }) else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)忽略未等待的工具结果：toolCallID=\(call.id), conversation=\(conversationID.uuidString.prefix(8))")
                }
                continue
            }
            switch batchResult {
            case .executed(let toolResult):
                let result = convertResult(toolResult)
                // 工具结果必须同时回写 assistant 消息中的嵌套 toolCall。
                // 消息渲染器从这里读取 awaitingUserResponse；只插入独立的
                // .tool 消息会让 UI 永远看到 result == nil，退化为 loading 行。
                messages.updateToolCallResult(
                    result,
                    toolCallID: call.id,
                    assistantMessageID: assistantMessageID,
                    in: conversationID
                )
                insertToolResultMessage(result, toolCallID: call.id, conversationID: conversationID, turnID: turnID)
                if result.awaitingUserResponse {
                    suspension = AgentLoopSuspension(
                        suspensionID: "userInput:\(call.id)", conversationID: conversationID,
                        toolCallID: call.id, kind: "userInput", payload: result.content
                    )
                    break
                }
                let (updated, outcome) = TurnReducer.reduce(runtime, event: .toolCallCompleted(toolCallID: call.id, result: result))
                runtime = updated
                if Self.verbose { Self.logger.info("\(Self.t)reducer after tool id=\(call.id), phase=\(String(describing: runtime.phase)), outcome=\(String(describing: outcome))") }
                if outcome != nil { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome!) ; return }
            case .blocked(let reason):
                let result = MessageToolResult(content: reason, isError: true)
                messages.updateToolCallResult(
                    result,
                    toolCallID: call.id,
                    assistantMessageID: assistantMessageID,
                    in: conversationID
                )
                insertToolResultMessage(result, toolCallID: call.id, conversationID: conversationID, turnID: turnID)
                let (updated, outcome) = TurnReducer.reduce(runtime, event: .toolCallCompleted(toolCallID: call.id, result: result))
                runtime = updated
                if Self.verbose { Self.logger.info("\(Self.t)reducer after blocked tool id=\(call.id), phase=\(String(describing: runtime.phase)), outcome=\(String(describing: outcome))") }
                if outcome != nil { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome!) ; return }
            case .needsUserResponse(let payload):
                let interactionSuspension = AgentLoopSuspension(
                    suspensionID: "userInput:\(call.id)", conversationID: conversationID,
                    toolCallID: call.id, kind: "userInput", payload: payload
                )
                let approvalResult = MessageToolResult(
                    content: interactionSuspension.payload,
                    isError: false,
                    awaitingUserResponse: true,
                    interactionState: .waiting
                )
                messages.updateToolCallResult(
                    approvalResult,
                    toolCallID: call.id,
                    assistantMessageID: assistantMessageID,
                    in: conversationID
                )
                insertToolResultMessage(
                    approvalResult,
                    toolCallID: call.id,
                    conversationID: conversationID,
                    turnID: turnID
                )
                suspension = interactionSuspension
            }
            if suspension != nil { break }
        }

        if let suspension {
            let event: TurnEvent = .toolNeedsUserInput(
                toolCallID: suspension.toolCallID ?? "", suspension: suspension
            )
            let (updated, outcome) = TurnReducer.reduce(runtime, event: event)
            runtimes[conversationID] = updated
            if let outcome { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome) }
            return
        }

        runtimes[conversationID] = runtime
        if Self.verbose { Self.logger.info("\(Self.t)handle batch end phase=\(String(describing: runtime.phase)), taskIsNil=\(runtime.task == nil)") }
        continueAfterToolResults(runtime: runtime, conversationID: conversationID, turnID: turnID)
    }

    /// 授权按钮可能在回合仍处于 `awaitingUser` 时被点击，也可能在应用重启后
    /// 才被点击。两种情况下都必须先把当前工具放回 `executingTools`，否则
    /// `authorizedCompleted` 事件没有状态机可以消费，结果只会停留在 ToolManager。
    @discardableResult
    private func prepareRuntimeForToolResult(
        conversationID: UUID,
        eventTurnID: UUID?,
        toolCall: AgentLoopToolCall
    ) -> Bool {
        if var runtime = runtimes[conversationID] {
            switch runtime.phase {
            case .executingTools:
                return true
            case .awaitingUser(let turnID, let assistantMessageID, let pending, let suspension):
                guard suspension.toolCallID == toolCall.id else { return false }
                let current = MessageToolCall(
                    id: toolCall.id,
                    name: toolCall.name,
                    arguments: toolCall.arguments
                )
                runtime.phase = .executingTools(
                    turnID: turnID,
                    assistantMessageID: assistantMessageID,
                    pendingToolCalls: [current] + pending.filter { $0.id != toolCall.id }
                )
                runtime.pendingSuspensions.removeValue(forKey: toolCall.id)
                runtimes[conversationID] = runtime
                return true
            default:
                return false
            }
        }

        // 进程重启后 runtimes 为空。assistant 消息是此时仍然可靠的持久化
        // 来源：它同时包含 turnID、assistant message ID 和完整工具调用列表。
        guard let assistantMessage = messages.messages(for: conversationID)
            .reversed()
            .first(where: { message in
                message.role == .assistant
                    && message.toolCalls?.contains(where: { $0.id == toolCall.id }) == true
            }),
            let toolCalls = assistantMessage.toolCalls,
            let current = toolCalls.first(where: { $0.id == toolCall.id }) else {
            return false
        }

        let turnID = eventTurnID ?? assistantMessage.turnID ?? UUID()
        let pending = toolCalls.filter { candidate in
            candidate.id == current.id
                || candidate.result == nil
                || candidate.result?.awaitingUserResponse == true
        }
        guard pending.contains(where: { $0.id == current.id }) else { return false }

        runtimes[conversationID] = TurnRuntime(
            phase: .executingTools(
                turnID: turnID,
                assistantMessageID: assistantMessage.id,
                pendingToolCalls: pending
            )
        )
        Self.logger.info(
            "\(Self.t)已从历史消息恢复授权工具回合 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), toolCall=\(toolCall.id)"
        )
        notify(.started(conversationID: conversationID, turnID: turnID))
        return true
    }

    /// 统一处理工具结果后的状态机推进：批次中若还有待执行工具，继续发出
    /// 工具事件；批次结束后才启动下一次 LLM 请求。
    private func continueAfterToolResults(
        runtime: TurnRuntime,
        conversationID: UUID,
        turnID: UUID
    ) {
        switch runtime.phase {
        case .requestingLLM:
            if Self.verbose { Self.logger.info("\(Self.t)🚛 工具批次完成，继续请求 LLM conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))") }
            launchAdvance(conversationID: conversationID, turnID: turnID)
        case .executingTools(let nextTurnID, let assistantMessageID, let remaining) where !remaining.isEmpty:
            notify(.toolCallsReceived(
                conversationID: conversationID,
                turnID: nextTurnID,
                assistantMessageID: assistantMessageID,
                toolCalls: remaining
            ))
        default:
            break
        }
    }

    /// 处理消息渲染器在用户授权后发起的单工具执行结果。
    ///
    /// 批量执行会先发送每个工具的 `completed` 事件，再发送
    /// `batchCompleted`；授权路径使用独立事件，避免这里重复消费批量结果。
    private func handleAuthorizedToolCompletion(
        conversationID: UUID,
        eventTurnID: UUID?,
        toolCall: AgentLoopToolCall,
        result toolResult: ToolCallResult
    ) {
        guard prepareRuntimeForToolResult(
            conversationID: conversationID,
            eventTurnID: eventTurnID,
            toolCall: toolCall
        ),
        var runtime = runtimes[conversationID] else {
            if Self.verbose {
                Self.logger.error("\(Self.t)忽略授权工具结果：找不到会话运行时 conversation=\(conversationID.uuidString.prefix(8))")
            }
            return
        }
        guard case .executingTools(let turnID, let assistantMessageID, let pending) = runtime.phase else {
            if Self.verbose {
                Self.logger.error("\(Self.t)忽略授权工具结果：当前状态不是 executingTools，conversation=\(conversationID.uuidString.prefix(8))")
            }
            return
        }
        guard eventTurnID == nil || eventTurnID == turnID else {
            if Self.verbose {
                Self.logger.error("\(Self.t)忽略授权工具结果：turnID 不匹配，conversation=\(conversationID.uuidString.prefix(8))")
            }
            return
        }
        guard pending.contains(where: { $0.id == toolCall.id }) else {
            if Self.verbose {
                Self.logger.error("\(Self.t)忽略未等待的授权工具结果：toolCallID=\(toolCall.id), conversation=\(conversationID.uuidString.prefix(8))")
            }
            return
        }

        let result = convertResult(toolResult)
        messages.updateToolCallResult(
            result,
            toolCallID: toolCall.id,
            assistantMessageID: assistantMessageID,
            in: conversationID,
            authorizationState: toolCall.authorizationState.rawValue
        )
        insertToolResultMessage(result, toolCallID: toolCall.id, conversationID: conversationID, turnID: turnID)

        if result.awaitingUserResponse {
            let suspension = AgentLoopSuspension(
                suspensionID: "userInput:\(toolCall.id)",
                conversationID: conversationID,
                toolCallID: toolCall.id,
                kind: "userInput",
                payload: result.content
            )
            let (updated, outcome) = TurnReducer.reduce(
                runtime,
                event: .toolNeedsUserInput(toolCallID: toolCall.id, suspension: suspension)
            )
            runtimes[conversationID] = updated
            if let outcome { finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome) }
            return
        }

        let (updated, outcome) = TurnReducer.reduce(
            runtime,
            event: .toolCallCompleted(toolCallID: toolCall.id, result: result)
        )
        runtime = updated
        runtimes[conversationID] = runtime
        if Self.verbose {
            Self.logger.info("\(Self.t)授权工具结果已处理 id=\(toolCall.id), phase=\(String(describing: runtime.phase))")
        }
        if let outcome {
            finishTurn(conversationID: conversationID, turnID: turnID, outcome: outcome)
        }
        continueAfterToolResults(runtime: runtime, conversationID: conversationID, turnID: turnID)
    }

    enum LLMRequestResult {
        case success(LLMResponse, assistantMessageID: UUID)
        case failure(reason: String)
    }

    /// 执行一次 LLM 流式请求，落库 assistant 消息。
    func performLLMRequest(conversationID: UUID, turnID: UUID) async -> LLMRequestResult {
        if Self.verbose { Self.logger.info("\(Self.t)LLM request begin conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))") }
        // 由上下文 Provider 统一决定发送完整历史还是压缩后的上下文。
        // AgentLoop 不读取全量历史，也不感知具体压缩策略。
        let history = await contextProvider.messagesForLLM(in: conversationID)

        // 计算工具 schema
        let automationLevel = conversations.automationLevel(for: conversationID)
        let rawTools = toolManager.allTools()
        let tools = automationLevel.allowsTools ? rawTools : []
        if Self.verbose {
            let firstFive = tools.prefix(5).map(\.name)
            Self.logger.info("\(Self.t)加载 AgentTool 数量: \(tools.count)，前5个: \(firstFive)，automationLevel=\(automationLevel.rawValue)，rawCount=\(rawTools.count)")
        }
        let language = languagePreference(for: conversationID)
        let schemas = tools.compactMap { tool -> LLMFunctionSchema? in
            LLMFunctionSchema(
                name: tool.name,
                description: tool.description(for: language),
                parameters: tool.inputSchema(for: language)
            )
        }
        let reasoningEffort = conversations.reasoningEffortOptional(for: conversationID)
            .flatMap { $0.rawValue }
        let modelName = conversations.modelName(for: conversationID)
        let resolvedProviderID = resolvedProviderID(for: conversationID)

        let llmHistory = history.map(\.llmMessage)
        var preparedMessages = llmHistory
        if let lifecycleHooks {
            let context = WillSendToLLMContext(
                messages: llmHistory,
                conversationID: conversationID
            )
            let result = await lifecycleHooks.runWillSendToLLM(context)
            preparedMessages = result.messages
        }

        if Self.verbose && Self.printMessages {
            for (index, message) in preparedMessages.enumerated() {
                let content = message.content.count > 200
                    ? "\(message.content.prefix(200))..."
                    : message.content
                Self.logger.info(
                    "\(Self.t)发送给 LLM 的提示词[\(index)] role=\(message.role.rawValue), content=\(content)"
                )
            }
        }

        let request = LLMRequest(
            conversationID: conversationID,
            messages: preparedMessages,
            model: modelName,
            tools: schemas.isEmpty ? nil : schemas,
            reasoningEffort: reasoningEffort
        )

        streaming.start(conversationID: conversationID)

        guard let streamingManager = llmManager as? any LLMStreamingProviding else {
            streaming.end(conversationID: conversationID)
            let error = AgentLoopError.unsupportedStreaming
            await appendError(in: conversationID, error: error, turnID: turnID)
            return .failure(reason: "unsupported streaming: \(error.localizedDescription)")
        }

        let timingRecorder = LLMStreamTimingRecorder()
        let bridge = StreamingBridge(streaming: streaming)
        do {
            let response = try await streamingManager.streamComplete(request) { [weak bridge, timingRecorder] chunk in
                if chunk.content?.isEmpty == false
                    || chunk.reasoningContent?.isEmpty == false
                    || !(chunk.toolCalls?.isEmpty ?? true) {
                    timingRecorder.markFirstOutput()
                }
                guard let bridge else { return }
                let piece = chunk.content ?? ""
                if let rc = chunk.reasoningContent, !rc.isEmpty {
                    await bridge.appendThinking(piece, conversationID: conversationID)
                } else {
                    await bridge.appendContent(piece, conversationID: conversationID)
                }
            }

            // 模型返回的 tool-call arguments 必须在落库前是 JSON 对象。
            // 否则坏的 assistant tool call 会进入历史，并在下一轮请求时触发
            // 上游的 HTTP 400。
            try response.validateToolCallArguments()

            let timing = timingRecorder.finish()

            if Self.verbose {
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    let toolNames = toolCalls.map { $0.name }
                    Self.logger.info("\(Self.t)👷 大模型返回工具调用: count=\(toolCalls.count), tools=\(toolNames), model=\(response.model ?? "unknown")")
                } else {
                    let responsePreview = String(
                        response.content
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                            .prefix(50)
                    )
                    Self.logger.info(
                        "\(Self.t)✅ 大模型返回纯文本响应 (无工具调用), model=\(response.model ?? "unknown"), content=\(responsePreview)"
                    )
                }
            }

            // 构建并落库 assistant 消息
            var assistant = Message(
                conversationID: conversationID,
                role: .assistant,
                content: response.content,
                turnID: turnID,
                providerID: response.model.flatMap { _ in nil } ?? nil,
                modelName: response.model,
                reasoningContent: response.reasoningContent,
                toolCalls: response.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
                inputTokenCount: response.inputTokenCount,
                outputTokenCount: response.outputTokenCount,
                cachedInputTokenCount: response.cachedInputTokenCount,
                cacheWriteInputTokenCount: response.cacheWriteInputTokenCount,
                cacheTotalInputTokenCount: response.cacheTotalInputTokenCount,
                responseID: response.responseID,
                rawResponseJSON: response.rawResponseJSON,
                rawStreamEventsJSON: response.rawStreamEventsJSON,
                stopReason: response.stopReason,
                latencyMs: timing.latencyMs,
                timeToFirstTokenMs: timing.timeToFirstTokenMs,
                streamingDurationMs: timing.streamingDurationMs
            )
            assistant.providerID = resolvedProviderID
            if let toolCalls = assistant.toolCalls {
                assistant.toolCalls = toolCalls.map { toolCall in
                    var enriched = toolCall
                    let agentToolCall = AgentLoopToolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    )
                    enriched.displayDescription = toolManager.displayDescription(for: agentToolCall)
                    let decision = toolManager.authorizationDecision(
                        for: agentToolCall,
                        conversationID: conversationID
                    )
                    enriched.authorizationState = switch decision {
                    case .requiresUserApproval:
                        ToolCallAuthorizationState.pendingAuthorization.rawValue
                    case .autoApproved:
                        ToolCallAuthorizationState.autoApproved.rawValue
                    case .blocked:
                        ToolCallAuthorizationState.userRejected.rawValue
                    }
                    return enriched
                }
            }
            messages.insertMessage(assistant, to: conversationID)
            streaming.end(conversationID: conversationID)
            if let lifecycleHooks {
                await lifecycleHooks.notifyDidReceiveLLMResponse(
                    DidReceiveLLMResponseContext(
                        response: response,
                        requestMessages: preparedMessages,
                        conversationID: conversationID
                    )
                )
            }

            return .success(response, assistantMessageID: assistant.id)

        } catch {
            streaming.end(conversationID: conversationID)
            await appendError(in: conversationID, error: error, turnID: turnID)
            return .failure(reason: String(describing: error))
        }
    }
}

// MARK: - Tool Execution

extension AgentLoopManager {
    func convertResult(_ result: KitAgentTool.ToolCallResult) -> MessageToolResult {
        MessageToolResult(
            content: result.content,
            duration: result.duration,
            isError: result.isError,
            imageAttachments: result.images.map {
                MessageImageAttachment(data: $0.data.base64EncodedString(), mimeType: $0.mimeType)
            },
            awaitingUserResponse: result.awaitingUserResponse,
            interactionState: result.interactionState.map {
                switch $0 {
                case .waiting: return .waiting
                case .answered(let answer): return .answered(answer)
                }
            }
        )
    }
}
