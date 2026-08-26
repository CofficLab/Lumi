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
    /// AgentLoop 只发布 LLM 结果；工具管理器负责消费该事件并执行批次。
    func handleAgentLoopEvent(_ event: AgentLoopEvent) {
        guard case .llmResponseReceived(let conversationID, let turnID, let toolCalls) = event,
              !toolCalls.isEmpty else { return }
        let policy: ToolExecutionPolicy
        switch conversations.automationLevel(for: conversationID) {
        case .chat: policy = .blockAll
        case .autonomous: policy = .autoExecute
        case .build: policy = .requireApprovalForHighRisk
        }
        let inputs = toolCalls.map { AgentLoopToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
        Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.t)无法执行 LLM 返回的工具调用：AgentLoopManager 已释放 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
                return
            }
            _ = await self.toolManager.executeBatch(inputs, policy: policy, conversationID: conversationID, turnID: turnID)
        }
    }

    /// 接收 ToolManager 的批量完成事件，推进当前回合状态机。
    func handleToolManagerEvent(_ event: ToolManagerEvent) {
        guard case .batchCompleted(let conversationID, let eventTurnID, let toolCalls, let results) = event else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)handle batch begin conversation=\(conversationID.uuidString.prefix(8)), turn=\(eventTurnID?.uuidString.prefix(8) ?? "nil"), calls=\(toolCalls.map { $0.id }), results=\(results.count)")
        }
        guard var runtime = runtimes[conversationID] else {
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

        let callsByID = Dictionary(uniqueKeysWithValues: toolCalls.map { ($0.id, MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)) })
        var suspension: AgentLoopSuspension?
        for (call, batchResult) in zip(toolCalls, results) {
            if Self.verbose {
                Self.logger.info("\(Self.t)handle batch result begin id=\(call.id), name=\(call.name), result=\(String(describing: batchResult))")
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
        if case .requestingLLM = runtime.phase {
            if Self.verbose { Self.logger.info("\(Self.t)🚛 工具批次完成，继续请求 LLM conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))") }
            launchAdvance(conversationID: conversationID, turnID: turnID)
        }
    }

    enum LLMRequestResult {
        case success(LLMResponse, assistantMessageID: UUID)
        case failure(reason: String)
    }

    /// 执行一次 LLM 流式请求，落库 assistant 消息。
    func performLLMRequest(conversationID: UUID, turnID: UUID) async -> LLMRequestResult {
        if Self.verbose { Self.logger.info("\(Self.t)LLM request begin conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))") }
        let history = messages.messages(for: conversationID)

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

        insertStatusMessage(
            conversationID: conversationID,
            content: String(localized: "status.thinking", defaultValue: "正在思考…")
        )

        var preparedHistory = history
        if let lifecycleHooks {
            let context = WillSendToLLMContext(
                messages: history.map(\.llmMessage),
                conversationID: conversationID
            )
            let result = await lifecycleHooks.runWillSendToLLM(context)
            preparedHistory = result.messages.map {
                messageFromLLMMessage($0, conversationID: conversationID)
            }
        }

        if Self.verbose && Self.printMessages {
            for (index, message) in preparedHistory.enumerated() {
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
            messages: preparedHistory.map(\.llmMessage),
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

        let bridge = StreamingBridge(streaming: streaming)
        do {
            let response = try await streamingManager.streamComplete(request) { [weak bridge] chunk in
                guard let bridge else { return }
                let piece = chunk.content ?? ""
                if let rc = chunk.reasoningContent, !rc.isEmpty {
                    await bridge.appendThinking(piece, conversationID: conversationID)
                } else {
                    await bridge.appendContent(piece, conversationID: conversationID)
                }
            }

            if Self.verbose {
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    let toolNames = toolCalls.map { $0.name }
                    Self.logger.info("\(Self.t)👷 大模型返回工具调用: count=\(toolCalls.count), tools=\(toolNames), model=\(response.model ?? "unknown")")
                } else {
                    Self.logger.info("\(Self.t)✅ 大模型返回纯文本响应 (无工具调用), model=\(response.model ?? "unknown")")
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
                outputTokenCount: response.outputTokenCount
            )
            assistant.providerID = resolvedProviderID
            if let toolCalls = assistant.toolCalls {
                assistant.toolCalls = toolCalls.map { toolCall in
                    var enriched = toolCall
                    enriched.displayDescription = toolManager.displayDescription(for: AgentLoopToolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    ))
                    return enriched
                }
            }
            messages.insertMessage(assistant, to: conversationID)
            streaming.end(conversationID: conversationID)
            if let lifecycleHooks {
                await lifecycleHooks.notifyDidReceiveLLMResponse(
                    DidReceiveLLMResponseContext(
                        response: response,
                        requestMessages: preparedHistory.map(\.llmMessage),
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
    /// 工具批次执行结果。
    enum AgentLoopBatchResult {
        /// 所有工具执行完成，结果已落库。
        case allCompleted(results: [(toolCallID: String, result: MessageToolResult)])
        /// 某个工具需要用户响应（审批或输入），已挂起。
        case suspended(suspension: AgentLoopSuspension, completedResults: [(toolCallID: String, result: MessageToolResult)])
    }

    /// 批量执行工具调用，内部处理授权判断和挂起。
    ///
    /// 调用 `toolManager.executeBatch`，根据策略执行或拒绝工具。
    /// 如果遇到需要审批或用户输入的工具，立即挂起并返回。
    func performToolBatch(
        _ toolCalls: [MessageToolCall],
        conversationID: UUID,
        turnID: UUID
    ) async -> AgentLoopBatchResult {
        // 映射 automationLevel → ToolExecutionPolicy
        let automationLevel = conversations.automationLevel(for: conversationID)
        let policy: ToolExecutionPolicy
        switch automationLevel {
        case .chat: policy = .blockAll
        case .autonomous: policy = .autoExecute
        case .build: policy = .requireApprovalForHighRisk
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)批量执行工具: count=\(toolCalls.count), automationLevel=\(automationLevel.rawValue), policy=\(policy)")
        }

        // 转换为 ToolCall
        let toolCallInputs = toolCalls.map { tc in
            AgentLoopToolCall(id: tc.id, name: tc.name, arguments: tc.arguments)
        }

        // 调用 executeBatch
        let batchResults = await toolManager.executeBatch(
            toolCallInputs,
            policy: policy,
            conversationID: conversationID,
            turnID: turnID
        )

        // 处理结果
        var completedResults: [(toolCallID: String, result: MessageToolResult)] = []

        for (toolCall, batchResult) in zip(toolCalls, batchResults) {
            switch batchResult {
            case .executed(let toolResult):
                let result = convertResult(toolResult)
                // 插入 status 消息
                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )
                // 检查是否需要挂起（ask_user 等工具）
                if result.awaitingUserResponse {
                    let suspension = AgentLoopSuspension(
                        suspensionID: "userInput:\(toolCall.id)",
                        conversationID: conversationID,
                        toolCallID: toolCall.id,
                        kind: "userInput",
                        payload: result.content
                    )
                    return .suspended(suspension: suspension, completedResults: completedResults)
                }
                completedResults.append((toolCall.id, result))

            case .blocked(let reason):
                // 工具被拒绝
                let result = MessageToolResult(content: reason, isError: true)
                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )
                completedResults.append((toolCall.id, result))

            case .needsUserResponse(let payload):
                // 工具需要审批
                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )
                let suspension = AgentLoopSuspension(
                    suspensionID: "userInput:\(toolCall.id)",
                    conversationID: conversationID,
                    toolCallID: toolCall.id,
                    kind: "userInput",
                    payload: payload
                )
                return .suspended(suspension: suspension, completedResults: completedResults)
            }
        }

        return .allCompleted(results: completedResults)
    }

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
