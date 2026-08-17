import AgentToolKit
import Foundation
import Combine
import os
import ProviderAgentLoop
import ProviderMessage
import ProviderLLMVendors
import ProviderToolManager
import ProviderMessageStreaming
import ProviderConversation
import SuperLogKit

// 消除 ProviderLLMVendors.ToolCall 与 AgentToolKit.ToolCall 的歧义
private typealias ToolCall = AgentToolKit.ToolCall

// MARK: - AgentLoopProvider + Loop

extension AgentLoopProvider {

    // MARK: - AgentLoopProviding (Turn Lifecycle)

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
        revision += 1
        postEvent(.turnStarted(conversationID: conversationID, turnID: turnID))

        let task: Task<AgentLoopOutcome, Never> = Task { @MainActor [weak self] in
            guard let self else { return .cancelled }
            return await self.executeTurnLoop(conversationID: conversationID, turnID: turnID)
        }
        tasks[conversationID] = task
        let outcome = await task.value
        tasks.removeValue(forKey: conversationID)
        turnIDs.removeValue(forKey: conversationID)
        revision += 1

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
            await activeTask.value
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

    // MARK: - Turn Loop

    private func executeTurnLoop(conversationID: UUID, turnID: UUID) async -> AgentLoopOutcome {
        guard responder != nil || llmProvider != nil else {
            await appendError(in: conversationID, content: "agent responder is not configured")
            failedConversations.insert(conversationID)
            return .failed("agent responder is not configured")
        }

        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            // Responder 路径：宿主注入自定义响应者（测试 / 嵌入场景）时直接
            // 调用一次并把结果落库，不做工具循环（responder 无工具能力）。
            if let responder, llmProvider == nil {
                let request = AgentLoopRequest(
                    conversationID: conversationID,
                    messages: messages.messages(for: conversationID)
                )
                do {
                    let content = try await responder(request)
                    try Task.checkCancellation()
                    let assistant = Message(
                        conversationID: conversationID,
                        role: .assistant,
                        content: content,
                        turnID: turnID
                    )
                    messages.insertMessage(assistant, to: conversationID)
                    postEvent(.messageSaved(conversationID: conversationID, messageID: assistant.id, role: assistant.role.rawValue))
                    states[conversationID] = .completed
                    postEvent(.turnCompleted(conversationID: conversationID, turnID: turnID))
                    postEvent(.turnFinished(conversationID: conversationID, turnID: turnID, reason: .completed))
                    return .completed
                } catch is CancellationError {
                    states[conversationID] = .cancelled
                    postEvent(.turnFinished(conversationID: conversationID, turnID: turnID, reason: .cancelled))
                    return .cancelled
                } catch {
                    await appendError(in: conversationID, content: String(describing: error), turnID: turnID)
                    failedConversations.insert(conversationID)
                    return .failed(String(describing: error))
                }
            }

            guard let llmProvider else {
                await appendError(in: conversationID, content: "LLM provider is not configured")
                failedConversations.insert(conversationID)
                return .failed("LLM provider is not configured")
            }

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
                    return .suspended("awaiting user response")
                }
                continue
            }

            // 会话设置是事实来源：automationLevel 决定是否附带工具。
            let automationLevel = conversations?.automationLevel(for: conversationID) ?? .build
            let tools = automationLevel.allowsTools ? (toolManager?.allTools() ?? []) : []
            let schemas = tools.compactMap { tool -> LLMFunctionSchema? in
                let language = languagePreference(for: conversationID)
                return LLMFunctionSchema(
                    name: tool.name,
                    description: tool.description(for: language),
                    parameters: tool.inputSchema(for: language)
                )
            }
            let reasoningEffort = conversations?.reasoningEffortOptional(for: conversationID)
                .flatMap { $0.rawValue }

            // LLM 请求前的消息准备钩子（对齐旧版 willSendToLLM）：
            // 详细度 / 语言 / 自动化级别等插件按注册顺序串行修改消息历史，
            // 注入 system 指令（不落库，仅本次请求生效）。
            var preparedHistory = history
            for preparer in messagePreparers {
                preparedHistory = await preparer(preparedHistory)
            }

            insertStatusMessage(
                conversationID: conversationID,
                content: String(localized: "status.thinking", defaultValue: "正在思考…")
            )

            let request = LLMRequest(
                conversationID: conversationID,
                messages: preparedHistory,
                model: conversations?.modelName(for: conversationID),
                tools: schemas.isEmpty ? nil : schemas,
                reasoningEffort: reasoningEffort
            )

            streaming?.start(conversationID: conversationID)

            let response: LLMResponse
            do {
                if let streamingProvider = llmProvider as? any LLMStreamingProviding {
                    // streaming 是 MainActor 隔离的存在类型，不能直接捕获进
                    // @Sendable 流式回调；用 @unchecked Sendable 桥接包装，
                    // 在回调内经 await 跳回 MainActor 写入。
                    let bridge = StreamingBridge(streaming: streaming)
                    response = try await streamingProvider.streamComplete(request) { [weak bridge] chunk in
                        guard let bridge else { return }
                        let piece = chunk.content ?? ""
                        if chunk.isThinking {
                            await bridge.appendThinking(piece, conversationID: conversationID)
                        } else {
                            await bridge.appendContent(piece, conversationID: conversationID)
                        }
                    }
                } else {
                    response = try await llmProvider.complete(request)
                }
            } catch {
                streaming?.end(conversationID: conversationID)
                await appendError(in: conversationID, content: error.localizedDescription, turnID: turnID)
                failedConversations.insert(conversationID)
                return .failed(String(describing: error))
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
                toolCalls: response.toolCalls,
                inputTokenCount: response.inputTokenCount,
                outputTokenCount: response.outputTokenCount
            )
            assistant.providerID = resolvedProviderID(for: conversationID)
            if let toolManager, let toolCalls = assistant.toolCalls {
                assistant.toolCalls = toolCalls.map { toolCall in
                    var enriched = toolCall
                    enriched.displayDescription = toolManager.displayDescription(for: ToolCall(
                        id: toolCall.id,
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    ))
                    return enriched
                }
            }
            messages.insertMessage(assistant, to: conversationID)
            postEvent(.messageSaved(conversationID: conversationID, messageID: assistant.id, role: assistant.role.rawValue))
            streaming?.end(conversationID: conversationID)

            // 无工具调用 → 回合完成。
            guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
                states[conversationID] = .completed
                postEvent(.turnCompleted(conversationID: conversationID, turnID: turnID))
                postEvent(.turnFinished(conversationID: conversationID, turnID: turnID, reason: .completed))
                return .completed
            }

            // 执行整批工具调用；挂起的调用记录后独立作答。
            var batchSuspensions: [String: AgentLoopSuspension] = [:]
            for toolCall in toolCalls where toolCall.result == nil {
                try? Task.checkCancellation()
                if cancelledConversations.contains(conversationID) {
                    return .cancelled
                }

                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )

                guard toolManager != nil else {
                    let result = MessageToolResult(content: "Tool manager is unavailable", isError: true)
                    messages.updateToolCallResult(result, toolCallID: toolCall.id, assistantMessageID: assistant.id, in: conversationID)
                    insertToolResultMessage(result, toolCallID: toolCall.id, conversationID: conversationID, turnID: turnID)
                    continue
                }

                var result = await executeToolCall(toolCall, conversationID: conversationID, turnID: turnID)
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
                postEvent(.turnFinished(conversationID: conversationID, turnID: turnID, reason: .awaitingUserResponse))
                return .suspended("awaiting user response")
            }

            // 工具结果已入历史，继续下一轮 LLM 请求。
        }

        states[conversationID] = .cancelled
        postEvent(.turnFinished(conversationID: conversationID, turnID: turnID, reason: .cancelled))
        return .cancelled
    }

    // MARK: - Tool Execution

    /// 授权边界：`chat` 拒绝工具、`autonomous` 直接执行、`build` 高风险需确认。
    private func executeToolCall(
        _ toolCall: MessageToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> MessageToolResult {
        guard let toolManager else {
            return MessageToolResult(content: "Tool manager is unavailable", isError: true)
        }
        let tool = ToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        let automationLevel = conversations?.automationLevel(for: conversationID) ?? .build
        switch automationLevel {
        case .chat:
            return MessageToolResult(
                content: "Tool execution was blocked because this conversation is in Chat mode.",
                isError: true
            )
        case .autonomous:
            return await convertResult(
                await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
            )
        case .build:
            let riskLevel = toolManager.riskLevel(for: tool) ?? .high
            guard riskLevel.requiresPermission else {
                return await convertResult(
                    await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
                )
            }
            return makeToolApprovalResult(for: toolCall, riskLevel: riskLevel, conversationID: conversationID)
        }
    }

    private func executeApprovedToolCall(_ toolCall: MessageToolCall, conversationID: UUID) async -> MessageToolResult {
        guard let toolManager else {
            return MessageToolResult(content: "Tool manager is unavailable", isError: true)
        }
        let tool = ToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        return await convertResult(
            await toolManager.execute(tool, conversationID: conversationID, turnID: turnIDs[conversationID])
        )
    }

    private func isToolApprovalGranted(_ answer: String) -> Bool {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            return true
        default:
            return false
        }
    }

    private func makeToolApprovalResult(
        for toolCall: MessageToolCall,
        riskLevel: CommandRiskLevel,
        conversationID: UUID
    ) -> MessageToolResult {
        let suspensionID = "approval:\(toolCall.id)"
        let operation = toolCall.displayDescription ?? toolCall.name
        let payload = ToolApprovalPayload(
            toolCallId: suspensionID,
            question: "此操作被判定为\(riskLevel.displayName)，是否允许执行？\n\(operation)",
            options: ["允许", "拒绝"],
            mode: "yes_no",
            conversationId: conversationID.uuidString,
            verbosity: "standard"
        )
        let content = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
            ?? "Unable to create tool approval request."
        let suspension = AgentLoopSuspension(
            suspensionID: suspensionID,
            conversationID: conversationID,
            toolCallID: toolCall.id,
            kind: Self.toolApprovalSuspensionKind,
            payload: content
        )
        suspensions[conversationID] = suspension
        return MessageToolResult(content: content, isError: false, awaitingUserResponse: true)
    }

    /// 把 `ToolCallResult` 转换为渲染层 `MessageToolResult`。
    private func convertResult(_ result: ToolCallResult) -> MessageToolResult {
        MessageToolResult(
            content: result.content,
            duration: result.duration,
            isError: result.isError,
            imageAttachments: result.images.map {
                MessageImageAttachment(data: $0.data.base64EncodedString(), mimeType: $0.mimeType)
            },
            awaitingUserResponse: result.awaitingUserResponse
        )
    }

    private func insertToolResultMessage(
        _ result: MessageToolResult,
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) {
        let toolMessage = Message(
            conversationID: conversationID,
            role: .tool,
            content: result.content,
            turnID: turnID,
            isError: result.isError,
            toolCallID: toolCallID
        )
        messages.insertMessage(toolMessage, to: conversationID)
        postEvent(.messageSaved(conversationID: conversationID, messageID: toolMessage.id, role: toolMessage.role.rawValue))
    }

    // MARK: - Incomplete Tool-Call Batch

    private func incompleteToolCallMessage(in conversationID: UUID) -> Message? {
        incompleteToolCallMessage(messages: messages.messages(for: conversationID))
    }

    private func incompleteToolCallMessage(messages: [Message]) -> Message? {
        let completedToolCallIDs = Set(
            messages.compactMap { message in
                message.role == .tool ? message.toolCallID : nil
            }
        )
        return messages.reversed().first { message in
            message.role == .assistant
                && message.toolCalls?.contains(where: {
                    $0.result == nil && !completedToolCallIDs.contains($0.id)
                }) == true
        }
    }

    private func latestAssistantToolCalls(in conversationID: UUID) -> [MessageToolCall]? {
        latestAssistantToolCalls(messages: messages.messages(for: conversationID))
    }

    private func latestAssistantToolCalls(messages: [Message]) -> [MessageToolCall]? {
        messages.reversed()
            .first(where: { $0.role == .assistant && !($0.toolCalls ?? []).isEmpty })?
            .toolCalls
    }

    /// 按顺序续跑中断的工具批次（resume 后已完成的调用跳过，下一调用可独立挂起）。
    /// - Returns: `true` 表示批次再次因用户输入挂起。
    private func executePendingToolCalls(
        in assistantMessage: Message,
        conversationID: UUID
    ) async -> Bool {
        await executePendingToolCalls(
            in: assistantMessage,
            conversationID: conversationID,
            snapshot: messages.messages(for: conversationID)
        )
    }

    private func executePendingToolCalls(
        in assistantMessage: Message,
        conversationID: UUID,
        snapshot: [Message]
    ) async -> Bool {
        guard let toolManager, let toolCalls = assistantMessage.toolCalls else {
            failedConversations.insert(conversationID)
            return false
        }

        var completedToolCallIDs = Set(
            snapshot.compactMap { message in
                message.role == .tool ? message.toolCallID : nil
            }
        )

        for toolCall in toolCalls where toolCall.result == nil && !completedToolCallIDs.contains(toolCall.id) {
            try? Task.checkCancellation()
            if cancelledConversations.contains(conversationID) {
                return false
            }

            insertStatusMessage(
                conversationID: conversationID,
                content: String(
                    localized: "status.executing-tool",
                    defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                )
            )

            var result = await executeToolCall(toolCall, conversationID: conversationID, turnID: turnIDs[conversationID])
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
            // 通用交互工具（AskUser 等）：构造用户输入挂起点。
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

            messages.updateToolCallResult(result, toolCallID: toolCall.id, assistantMessageID: assistantMessage.id, in: conversationID)
            insertToolResultMessage(result, toolCallID: toolCall.id, conversationID: conversationID, turnID: turnIDs[conversationID])
            completedToolCallIDs.insert(toolCall.id)

            if result.awaitingUserResponse {
                return true
            }
        }

        return false
    }

    // MARK: - Helpers

    private func insertStatusMessage(conversationID: UUID, content: String) {
        let status = Message(
            conversationID: conversationID,
            role: .status,
            content: content,
            metadata: ["isTransientStatus": "true"]
        )
        messages.insertMessage(status, to: conversationID)
    }

    private func appendError(in conversationID: UUID, content: String, turnID: UUID? = nil) async {
        let errorMessage = Message(
            conversationID: conversationID,
            role: .error,
            content: content,
            turnID: turnID
        )
        messages.insertMessage(errorMessage, to: conversationID)
        postEvent(.messageSaved(conversationID: conversationID, messageID: errorMessage.id, role: errorMessage.role.rawValue))
    }

    private func languagePreference(for conversationID: UUID) -> LanguagePreference {
        let language = conversations?.language(for: conversationID) ?? .chinese
        switch language {
        case .chinese: return .chinese
        case .english: return .english
        }
    }

    private func resolvedProviderID(for conversationID: UUID) -> String? {
        conversations?.providerID(for: conversationID)
    }

    private func postEvent(_ event: AgentLoopEvent) {
        eventHandler?(event)
    }

    private static let toolApprovalSuspensionKind = "toolApproval"
}

// MARK: - Tool Approval Payload（复刻旧版 ToolApprovalPayload）

private struct ToolApprovalPayload: Codable {
    let toolCallId: String
    let question: String
    let options: [String]
    let mode: String
    let conversationId: String
    let verbosity: String
}

/// 把 MainActor 隔离的流式 store 桥接为 `@Sendable` 可捕获值。
///
/// `MessageStreamingProviding` 是 MainActor 隔离的存在类型，不能直接捕获进
/// `LLMStreamingProviding.streamComplete` 的 `@Sendable` 回调；本包装类标记
/// `@unchecked Sendable`，回调内经 `await` 跳回 MainActor 写入，保证对
/// `@Published` 的写安全。
private final class StreamingBridge: @unchecked Sendable {
    private let streaming: (any MessageStreamingProviding)?

    init(streaming: (any MessageStreamingProviding)?) {
        self.streaming = streaming
    }

    @MainActor
    func appendContent(_ content: String, conversationID: UUID) {
        streaming?.appendContent(content, conversationID: conversationID)
    }

    @MainActor
    func appendThinking(_ content: String, conversationID: UUID) {
        streaming?.appendThinking(content, conversationID: conversationID)
    }
}
