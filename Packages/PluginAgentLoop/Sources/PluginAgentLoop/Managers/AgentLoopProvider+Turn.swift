import AgentToolKit
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import SuperLogKit

// MARK: - Turn Lifecycle

extension AgentLoopProvider {
    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)开始执行回合 - conversationID: \(conversationID)")
        }

        guard tasks[conversationID] == nil else {
            return .failed("turn already running")
        }

        cancelledConversations.remove(conversationID)
        failedConversations.remove(conversationID)

        let turnID = UUID()
        turnIDs[conversationID] = turnID
        states[conversationID] = .running

        let task: Task<AgentLoopOutcome, Never> = Task { @MainActor [weak self] in
            guard let self else { return .cancelled }
            return await self.executeTurnLoop(conversationID: conversationID, turnID: turnID)
        }
        tasks[conversationID] = task
        let outcome = await task.value
        tasks.removeValue(forKey: conversationID)
        turnIDs.removeValue(forKey: conversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)回合执行完成 - conversationID: \(conversationID), outcome: \(String(describing: outcome))")
        }

        return outcome
    }

    /// 恢复被挂起的回合：把用户回答写入工具结果，继续执行同一批次中剩余调用；
    /// 批次全部终态后开启新一轮 LLM 请求。
    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)恢复回合 - conversationID: \(conversationID), suspensionID: \(request.suspensionID)")
        }

        // 挂起工具可能在 runTurn 外层收尾前就发布了 messageSaved，用户可能
        // 提前作答。等待生命周期完全结束，避免被当成并发回合取消。
        if let activeTask = tasks[conversationID] {
            _ = await activeTask.value
            tasks.removeValue(forKey: conversationID)
        }

        guard let suspension = pendingSuspensions[conversationID]?.values.first(where: {
            $0.suspensionID == request.suspensionID
        }) ?? suspensions[conversationID] else {
            throw AgentLoopError.invalidResumeRequest
        }
        guard suspension.suspensionID == request.suspensionID,
              let toolCallID = suspension.toolCallID,
              let assistantMessage = messages.messages(for: conversationID)
              .reversed()
              .first(where: { $0.role == .assistant && $0.toolCalls?.contains(where: { $0.id == toolCallID }) == true }),
              let toolCall = assistantMessage.toolCalls?.first(where: { $0.id == toolCallID })
        else {
            throw AgentLoopError.invalidResumeRequest
        }

        // 授权类挂起：批准才执行；拒绝写入拒绝结果。其余（ask_user 等）：
        // 直接把用户回答作为工具结果回传。
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

        // 更新 assistant 消息内的展示快照。
        messages.updateToolCallResult(result, toolCallID: toolCallID, assistantMessageID: assistantMessage.id, in: conversationID)
        // 把用户回答合并进已落库的 .tool 消息（LLM 下一轮可见）。
        if let pendingToolMessage = messages.messages(for: conversationID)
            .last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
            messages.updateMessage(
                id: pendingToolMessage.id,
                in: conversationID,
                content: suspension.kind == Self.toolApprovalSuspensionKind ? result.content : request.answer
            )
        }

        suspensions.removeValue(forKey: conversationID)
        if let matchingToolCallID = pendingSuspensions[conversationID]?.first(where: {
            $0.value.suspensionID == request.suspensionID
        })?.key {
            pendingSuspensions[conversationID]?.removeValue(forKey: matchingToolCallID)
        }
        if pendingSuspensions[conversationID]?.isEmpty == true {
            pendingSuspensions.removeValue(forKey: conversationID)
        }

        // 同一 assistant 批次中可能还有未执行调用：继续执行，仍可能独立挂起。
        if let incomplete = incompleteToolCallMessage(in: conversationID) {
            let suspendedAgain = await executePendingToolCalls(in: incomplete, conversationID: conversationID)
            if suspendedAgain {
                states[conversationID] = .suspended
                return .suspended("awaiting user response")
            }
        }

        let latestCalls = latestAssistantToolCalls(in: conversationID)
        guard latestCalls?.isTerminalToolBatch == true else {
            states[conversationID] = .suspended
            return .suspended("awaiting user response")
        }

        states[conversationID] = .running
        if Self.verbose {
            Self.logger.info("\(Self.t)回合恢复完成 - conversationID: \(conversationID)")
        }
        // 答案已写入持久历史，新一轮无需特殊 resume 模式。
        return try await runTurn(in: conversationID)
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)取消回合 - conversationID: \(conversationID)")
        }
        cancelledConversations.insert(conversationID)
        suspensions.removeValue(forKey: conversationID)
        pendingSuspensions.removeValue(forKey: conversationID)
        awaitingConversations.remove(conversationID)
        states[conversationID] = .cancelled
        tasks[conversationID]?.cancel()
        tasks.removeValue(forKey: conversationID)
    }
}

// MARK: - Turn Loop

extension AgentLoopProvider {
    private func executeTurnLoop(conversationID: UUID, turnID: UUID) async -> AgentLoopOutcome {
        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            let history = messages.messages(for: conversationID)

            // 先续跑未完成的工具批次，再向 LLM 请求新响应。
            if let pendingAssistantMessage = incompleteToolCallMessage(messages: history) {
                let suspended = await executePendingToolCalls(
                    in: pendingAssistantMessage,
                    conversationID: conversationID,
                    snapshot: history
                )
                if suspended {
                    states[conversationID] = .suspended
                    if Self.verbose {
                        Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: suspended (pending tool calls)")
                    }
                    return .suspended("awaiting user response")
                }
                continue
            }

            // 会话设置是事实来源：automationLevel 决定是否附带工具。
            let automationLevel = conversations.automationLevel(for: conversationID)
            let rawTools = toolManager.allTools()
            let tools = automationLevel.allowsTools ? rawTools : []
            if Self.verbose {
                let firstFive = tools.prefix(5).map(\.name)
                Self.logger.info("\(Self.t)加载 AgentTool 数量: \(tools.count)，前5个: \(firstFive)，automationLevel=\(automationLevel.rawValue)，rawCount=\(rawTools.count)")
            }
            let schemas = tools.compactMap { tool -> LLMFunctionSchema? in
                let language = languagePreference(for: conversationID)
                return LLMFunctionSchema(
                    name: tool.name,
                    description: tool.description(for: language),
                    parameters: tool.inputSchema(for: language)
                )
            }
            let reasoningEffort = conversations.reasoningEffortOptional(for: conversationID)
                .flatMap { $0.rawValue }

            // LLM 请求前的消息准备钩子：
            // 详细度 / 语言 / 自动化级别等插件按注册顺序串行修改消息历史，
            // 注入 system 指令（不落库，仅本次请求生效）。
            let preparedHistory = history

            insertStatusMessage(
                conversationID: conversationID,
                content: String(localized: "status.thinking", defaultValue: "正在思考…")
            )

            let request = LLMRequest(
                conversationID: conversationID,
                messages: preparedHistory.map(\.llmMessage),
                model: conversations.modelName(for: conversationID),
                tools: schemas.isEmpty ? nil : schemas,
                reasoningEffort: reasoningEffort
            )

            streaming.start(conversationID: conversationID)

            let response: LLMResponse
            do {
                guard let streamingManager = llmManager as? any LLMStreamingProviding else {
                    streaming.end(conversationID: conversationID)
                    let error = AgentLoopError.unsupportedStreaming
                    await appendError(in: conversationID, error: error, turnID: turnID)
                    failedConversations.insert(conversationID)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: failed (unsupported streaming)")
                    }
                    return .failed("unsupported streaming: \(error.localizedDescription)")
                }
                let bridge = StreamingBridge(streaming: streaming)
                response = try await streamingManager.streamComplete(request) { [weak bridge] chunk in
                    guard let bridge else { return }
                    let piece = chunk.content ?? ""
                    if let rc = chunk.reasoningContent, !rc.isEmpty {
                        await bridge.appendThinking(piece, conversationID: conversationID)
                    } else {
                        await bridge.appendContent(piece, conversationID: conversationID)
                    }
                }
            } catch {
                streaming.end(conversationID: conversationID)
                await appendError(in: conversationID, error: error, turnID: turnID)
                failedConversations.insert(conversationID)
                if Self.verbose {
                    Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: failed (stream error)")
                }
                return .failed(String(describing: error))
            }

            if Self.verbose {
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    let toolNames = toolCalls.map { $0.name }
                    Self.logger.info("\(Self.t)大模型返回工具调用: count=\(toolCalls.count), tools=\(toolNames), model=\(response.model ?? "unknown")")
                } else {
                    Self.logger.info("\(Self.t)大模型返回纯文本响应 (无工具调用), model=\(response.model ?? "unknown")")
                }
            }

            // 落库 assistant 消息（临时行用独立稳定 id，与最终行 id 永不冲突）。
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
            assistant.providerID = resolvedProviderID(for: conversationID)
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

            // 无工具调用 → 回合完成。
            guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
                states[conversationID] = .completed
                if Self.verbose {
                    Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: completed")
                }
                return .completed
            }

            // 执行整批工具调用；挂起的调用记录后独立作答。
            var batchSuspensions: [String: AgentLoopSuspension] = [:]
            for toolCall in toolCalls where toolCall.result == nil {
                try? Task.checkCancellation()
                if cancelledConversations.contains(conversationID) {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: cancelled (during tool execution)")
                    }
                    return .cancelled
                }

                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )

                var result = await executeToolCall(toolCall, conversationID: conversationID, turnID: turnID)
                if Self.verbose {
                    Self.logger.info("\(Self.t)工具执行结果: tool=\(toolCall.name), awaitingUserResponse=\(result.awaitingUserResponse), isError=\(result.isError), contentLen=\(result.content.count)")
                }
                // 工具实现拿不到外层 tool-call id：此处绑定后再持久化挂起点。
                if result.awaitingUserResponse, let suspension = suspensions[conversationID],
                   suspension.toolCallID == nil {
                    let bound = AgentLoopSuspension(
                        suspensionID: suspension.suspensionID,
                        conversationID: suspension.conversationID,
                        toolCallID: toolCall.id,
                        kind: suspension.kind,
                        payload: suspension.payload
                    )
                    suspensions[conversationID] = bound
                    result = MessageToolResult(
                        content: result.content,
                        isError: result.isError,
                        awaitingUserResponse: true
                    )
                }
                // 通用交互工具（AskUser 等）：返回 awaitingUserResponse 但未携带
                // 现成 suspension 时，从 toolCall 构造用户输入挂起点。
                if result.awaitingUserResponse, suspensions[conversationID] == nil {
                    let generic = AgentLoopSuspension(
                        suspensionID: "userInput:\(toolCall.id)",
                        conversationID: conversationID,
                        toolCallID: toolCall.id,
                        kind: "userInput",
                        payload: result.content
                    )
                    suspensions[conversationID] = generic
                }

                messages.updateToolCallResult(result, toolCallID: toolCall.id, assistantMessageID: assistant.id, in: conversationID)
                insertToolResultMessage(result, toolCallID: toolCall.id, conversationID: conversationID, turnID: turnID)

                if result.awaitingUserResponse {
                    if let suspension = suspensions[conversationID] {
                        batchSuspensions[toolCall.id] = suspension
                    }
                }
            }

            if !batchSuspensions.isEmpty {
                pendingSuspensions[conversationID] = batchSuspensions
                suspensions[conversationID] = batchSuspensions.values.first
                awaitingConversations.insert(conversationID)
                states[conversationID] = .suspended
                if Self.verbose {
                    Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: suspended (batch awaiting user response)")
                }
                return .suspended("awaiting user response")
            }

            // 工具结果已入历史，继续下一轮 LLM 请求。
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)退出回合循环 - conversationID: \(conversationID), reason: cancelled")
        }
        states[conversationID] = .cancelled
        return .cancelled
    }
}
