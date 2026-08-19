import AgentToolKit
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import SuperLogKit

// MARK: - LLM Request

extension AgentLoopProvider {
    enum LLMRequestResult {
        case success(LLMResponse, assistantMessageID: UUID)
        case failure(reason: String)
    }

    /// 执行一次 LLM 流式请求，落库 assistant 消息。
    func performLLMRequest(conversationID: UUID, turnID: UUID) async -> LLMRequestResult {
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

        let request = LLMRequest(
            conversationID: conversationID,
            messages: history.map(\.llmMessage),
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
                    Self.logger.info("\(Self.t)大模型返回工具调用: count=\(toolCalls.count), tools=\(toolNames), model=\(response.model ?? "unknown")")
                } else {
                    Self.logger.info("\(Self.t)大模型返回纯文本响应 (无工具调用), model=\(response.model ?? "unknown")")
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

            return .success(response, assistantMessageID: assistant.id)

        } catch {
            streaming.end(conversationID: conversationID)
            await appendError(in: conversationID, error: error, turnID: turnID)
            return .failure(reason: String(describing: error))
        }
    }
}

// MARK: - Tool Execution

extension AgentLoopProvider {
    /// 工具执行结果（本地枚举，区别于 AgentToolKit.ToolCallResult）。
    enum AgentLoopToolCallResult {
        case completed(MessageToolResult)
        case needsApproval(AgentLoopSuspension)
        case needsUserInput(AgentLoopSuspension)
    }

    /// 执行一次工具调用，返回结果或挂起点。
    func performToolCall(
        _ toolCall: MessageToolCall,
        conversationID: UUID,
        turnID: UUID
    ) async -> AgentLoopToolCallResult {
        insertStatusMessage(
            conversationID: conversationID,
            content: String(
                localized: "status.executing-tool",
                defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
            )
        )

        let result = await executeToolCall(toolCall, conversationID: conversationID, turnID: turnID)

        if Self.verbose {
            Self.logger.info("\(Self.t)工具执行结果: tool=\(toolCall.name), awaitingUserResponse=\(result.awaitingUserResponse), isError=\(result.isError), contentLen=\(result.content.count)")
        }

        // 处理挂起
        if result.awaitingUserResponse {
            // 检查是否已有挂起点（来自工具内部）
            if let suspension = runtimes[conversationID]?.activeSuspension, suspension.toolCallID == nil {
                let bound = AgentLoopSuspension(
                    suspensionID: suspension.suspensionID,
                    conversationID: suspension.conversationID,
                    toolCallID: toolCall.id,
                    kind: suspension.kind,
                    payload: suspension.payload
                )
                runtimes[conversationID]?.pendingSuspensions[toolCall.id] = bound
                return .needsUserInput(bound)
            }

            // 通用交互工具（ask_user 等）
            let generic = AgentLoopSuspension(
                suspensionID: "userInput:\(toolCall.id)",
                conversationID: conversationID,
                toolCallID: toolCall.id,
                kind: "userInput",
                payload: result.content
            )
            return .needsUserInput(generic)
        }

        return .completed(result)
    }

    /// 授权边界：chat 拒绝工具、autonomous 直接执行、build 高风险需确认。
    func executeToolCall(
        _ toolCall: MessageToolCall,
        conversationID: UUID,
        turnID: UUID
    ) async -> MessageToolResult {
        let tool = AgentLoopToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        let automationLevel = conversations.automationLevel(for: conversationID)
        if Self.verbose {
            let risk = toolManager.riskLevel(for: tool)
            Self.logger.info("\(Self.t)执行工具前: tool=\(toolCall.name), automationLevel=\(automationLevel.rawValue), riskLevel=\(String(describing: risk)), argumentsLen=\(toolCall.arguments.count)")
        }
        switch automationLevel {
        case .chat:
            return MessageToolResult(
                content: "Tool execution was blocked because this conversation is in Chat mode.",
                isError: true
            )
        case .autonomous:
            return convertResult(
                await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
            )
        case .build:
            let riskLevel = toolManager.riskLevel(for: tool) ?? .high
            guard riskLevel.requiresPermission else {
                return convertResult(
                    await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
                )
            }
            return makeToolApprovalResult(for: toolCall, riskLevel: riskLevel, conversationID: conversationID)
        }
    }

    func executeApprovedToolCall(_ toolCall: MessageToolCall, conversationID: UUID) async -> MessageToolResult {
        let tool = AgentLoopToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        return convertResult(
            await toolManager.execute(tool, conversationID: conversationID, turnID: runtimes[conversationID]?.turnID)
        )
    }

    func isToolApprovalGranted(_ answer: String) -> Bool {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            return true
        default:
            return false
        }
    }

    func makeToolApprovalResult(
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
        // 存储到 runtime 的 pendingSuspensions
        runtimes[conversationID, default: TurnRuntime()].pendingSuspensions[toolCall.id] = suspension
        return MessageToolResult(
            content: content,
            isError: false,
            awaitingUserResponse: true,
            interactionState: .waiting
        )
    }

    func convertResult(_ result: AgentToolKit.ToolCallResult) -> MessageToolResult {
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
}

// MARK: - Tool Approval Payload

private struct ToolApprovalPayload: Codable {
    let toolCallId: String
    let question: String
    let options: [String]
    let mode: String
    let conversationId: String
    let verbosity: String
}
