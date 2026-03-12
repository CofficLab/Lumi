import Foundation
import MagicKit
import OSLog
import SwiftUI

@MainActor
private struct TurnContext {
    var currentDepth: Int = 0
    var pendingToolCalls: [ToolCall] = []
    var currentProviderId: String = ""
    var chainStartedAt: Date?
    var consecutiveEmptyToolTurns: Int = 0
    var lastToolSignature: String?
    var repeatedToolSignatureCount: Int = 0
    var recentToolSignatures: [String] = []
}

/// 对话轮次事件
enum ConversationTurnEvent: Sendable {
    case responseReceived(ChatMessage, conversationId: UUID)
    case streamChunk(content: String, messageId: UUID, conversationId: UUID)
    case streamEvent(eventType: StreamEventType, content: String, rawEvent: String, messageId: UUID, conversationId: UUID)
    case streamStarted(messageId: UUID, conversationId: UUID)
    case streamFinished(message: ChatMessage, conversationId: UUID)
    case toolResultReceived(ChatMessage, conversationId: UUID)
    case permissionRequested(PermissionRequest, conversationId: UUID)
    case maxDepthReached(currentDepth: Int, maxDepth: Int, conversationId: UUID)
    case completed(conversationId: UUID)
    case error(Error, conversationId: UUID)
    case shouldContinue(depth: Int, conversationId: UUID)
}

/// 对话轮次处理 ViewModel
@MainActor
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    // MARK: - 事件流

    var events: AsyncStream<ConversationTurnEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    private var eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation?

    // MARK: - 服务依赖

    private let llmService: LLMService
    private let toolExecutionService: ToolExecutionService
    private let promptService: PromptService

    // MARK: - 会话上下文

    private var turnContexts: [UUID: TurnContext] = [:]
    private let maxDepth = 16
    private let maxToolResultLength = 4_000

    /// 连续重复同一工具签名（名称+参数）达到多少次视为循环
    private let repeatedToolSignatureThreshold = 10

    /// 在最近窗口中同一签名出现多少次视为循环
    private let repeatedToolWindowThreshold = 10
    private let createAndAssignTaskToolName = "create_and_assign_task"

    /// 仅转发必要的流式事件，避免高频无用事件（如 thinking_delta）压垮主线程。
    private nonisolated static func shouldForwardStreamEvent(_ eventType: StreamEventType) -> Bool {
        switch eventType {
        case .ping, .contentBlockStart, .contentBlockStop, .messageDelta, .signatureDelta:
            return true
        case .messageStart, .messageStop, .unknown, .contentBlockDelta, .thinkingDelta, .inputJsonDelta, .textDelta:
            return false
        }
    }

    // MARK: - 初始化

    init(
        llmService: LLMService,
        toolExecutionService: ToolExecutionService,
        promptService: PromptService
    ) {
        self.llmService = llmService
        self.toolExecutionService = toolExecutionService
        self.promptService = promptService
    }

    // MARK: - 对话轮次处理

    var enableStreaming: Bool = true

    func processTurn(
        conversationId: UUID,
        depth: Int = 0,
        config: LLMConfig,
        messages: [ChatMessage],
        chatMode: ChatMode,
        tools: [AgentTool],
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        guard depth <= maxDepth else {
            eventContinuation?.yield(.maxDepthReached(currentDepth: depth, maxDepth: maxDepth, conversationId: conversationId))
            return
        }
        let isFinalStep = depth == maxDepth

        var context = turnContexts[conversationId] ?? TurnContext()
        if depth == 0 {
            context = TurnContext()
            context.chainStartedAt = Date()
        }
        if context.chainStartedAt == nil {
            context.chainStartedAt = Date()
        }
        context.currentDepth = depth
        context.currentProviderId = config.providerId
        turnContexts[conversationId] = context

        if Self.verbose {
            os_log("\(Self.t)🚀 [\(conversationId)] 开始处理轮次 (深度：\(depth), 模式：\(chatMode.displayName), 流式：\(self.enableStreaming))")
        }

        let availableTools: [AgentTool] = (chatMode.allowsTools && !isFinalStep)
            ? tools.filter { tool in
                // 多 Worker 工具仅在允许多 Worker 的模式下启用
                if tool.name == createAndAssignTaskToolName {
                    return chatMode.allowsMultiWorker
                }
                return true
            }
            : []

        var effectiveMessages = messages
        if isFinalStep {
            effectiveMessages.append(ChatMessage.maxDepthFinalStepReminderMessage())
        }

        do {
            let responseMsg: ChatMessage

            if enableStreaming {
                responseMsg = try await processStreamingTurn(
                    conversationId: conversationId,
                    config: config,
                    messages: effectiveMessages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            } else {
                responseMsg = try await processNonStreamingTurn(
                    conversationId: conversationId,
                    config: config,
                    messages: effectiveMessages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            }

            let hasContent = !responseMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasToolCalls = !(responseMsg.toolCalls?.isEmpty ?? true)

            context = turnContexts[conversationId] ?? TurnContext()
            if hasToolCalls && !hasContent {
                context.consecutiveEmptyToolTurns += 1
            } else {
                context.consecutiveEmptyToolTurns = 0
            }
            turnContexts[conversationId] = context

            // 防止模型陷入“空文本 + 工具调用”循环，导致长时间卡住。
            if context.consecutiveEmptyToolTurns >= 3 {
                if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                }
                context.pendingToolCalls.removeAll()
                turnContexts[conversationId] = context
                let error = NSError(
                    domain: "ConversationTurn",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "检测到连续空响应工具循环，已自动中止本轮。"]
                )
                eventContinuation?.yield(.error(error, conversationId: conversationId))
                os_log(.error, "\(Self.t)❌ [\(conversationId)] 连续空响应工具循环，已中止")
                return
            }

            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if isFinalStep {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                    var broken = turnContexts[conversationId] ?? TurnContext()
                    broken.pendingToolCalls.removeAll()
                    turnContexts[conversationId] = broken
                // 在 UI 中给出明确的助手提示，而不是静默结束
                let explainMessage = ChatMessage.maxDepthToolLimitMessage(
                    languagePreference: languagePreference,
                    currentDepth: depth,
                    maxDepth: maxDepth
                )
                eventContinuation?.yield(.responseReceived(explainMessage, conversationId: conversationId))
                    eventContinuation?.yield(.completed(conversationId: conversationId))
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ [\(conversationId)] 最后一步仍请求工具，已忽略并结束本轮")
                    }
                    return
                }

                if Self.verbose {
                    os_log("\(Self.t)🔧 [\(conversationId)] 收到 \(toolCalls.count) 个工具调用")
                }

                context = turnContexts[conversationId] ?? TurnContext()
                context.pendingToolCalls = toolCalls
                turnContexts[conversationId] = context

                let firstTool = context.pendingToolCalls.removeFirst()

                // 检测重复工具循环（同名 + 同参数）
                let normalizedArgs = firstTool.arguments
                    .replacingOccurrences(
                        of: "\\s+",
                        with: "",
                        options: .regularExpression
                    )
                let signaturePrefix = String(normalizedArgs.prefix(512))
                let signature = "\(firstTool.name)|\(signaturePrefix)"
                if context.lastToolSignature == signature {
                    context.repeatedToolSignatureCount += 1
                } else {
                    context.lastToolSignature = signature
                    context.repeatedToolSignatureCount = 1
                }
                context.recentToolSignatures.append(signature)
                if context.recentToolSignatures.count > 6 {
                    context.recentToolSignatures.removeFirst(context.recentToolSignatures.count - 6)
                }
                turnContexts[conversationId] = context

                let sameSignatureInWindow = context.recentToolSignatures.filter { $0 == signature }.count
                if context.repeatedToolSignatureCount >= repeatedToolSignatureThreshold
                    || sameSignatureInWindow >= repeatedToolWindowThreshold {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                    var broken = turnContexts[conversationId] ?? TurnContext()
                    broken.pendingToolCalls.removeAll()
                    turnContexts[conversationId] = broken
                    let explainMessage = ChatMessage.repeatedToolLoopMessage(
                        languagePreference: languagePreference,
                        tool: firstTool,
                        repeatedCount: context.repeatedToolSignatureCount,
                        windowCount: sameSignatureInWindow
                    )
                    eventContinuation?.yield(.responseReceived(explainMessage, conversationId: conversationId))
                    let error = NSError(
                        domain: "ConversationTurn",
                        code: 410,
                        userInfo: [NSLocalizedDescriptionKey: "检测到重复工具调用循环，已自动中止本轮。"]
                    )
                    eventContinuation?.yield(.error(error, conversationId: conversationId))
                    os_log(.error, "\(Self.t)❌ [\(conversationId)] 重复工具调用循环，已中止: \(firstTool.name)")
                    return
                }

                await handleToolCall(
                    firstTool,
                    conversationId: conversationId,
                    languagePreference: languagePreference,
                    autoApproveRisk: autoApproveRisk
                )
            } else {
                context = turnContexts[conversationId] ?? TurnContext()
                context.lastToolSignature = nil
                context.repeatedToolSignatureCount = 0
                context.recentToolSignatures.removeAll(keepingCapacity: false)
                turnContexts[conversationId] = context
                eventContinuation?.yield(.completed(conversationId: conversationId))
                if Self.verbose {
                    os_log("\(Self.t)✅ [\(conversationId)] 轮次完成（无工具）")
                }
            }
        } catch {
            var failedContext = turnContexts[conversationId] ?? TurnContext()
            failedContext.pendingToolCalls.removeAll()
            turnContexts[conversationId] = failedContext

            let explainMessage = ChatMessage.requestFailedMessage(languagePreference: languagePreference, error: error)
            eventContinuation?.yield(.responseReceived(explainMessage, conversationId: conversationId))
            eventContinuation?.yield(.error(error, conversationId: conversationId))
            os_log(.error, "\(Self.t)❌ [\(conversationId)] 对话处理失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 流式响应处理

    private func processStreamingTurn(
        conversationId: UUID,
        config: LLMConfig,
        messages: [ChatMessage],
        availableTools: [AgentTool],
        languagePreference: LanguagePreference
    ) async throws -> ChatMessage {
        let messageId = UUID()
        eventContinuation?.yield(.streamStarted(messageId: messageId, conversationId: conversationId))
        let continuation = eventContinuation

        let responseMsg = try await llmService.sendStreamingMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        ) { [weak self] chunk in
            guard let self = self else { return }
            if let eventType = chunk.eventType {
                if Self.shouldForwardStreamEvent(eventType) {
                    let content: String = (eventType == .inputJsonDelta) ? (chunk.partialJson ?? "") : (chunk.content ?? "")
                    let rawEvent = chunk.rawEvent ?? ""
                    continuation?.yield(
                        .streamEvent(
                            eventType: eventType,
                            content: content,
                            rawEvent: rawEvent,
                            messageId: messageId,
                            conversationId: conversationId
                        )
                    )
                }
            }

            if let content = chunk.content, chunk.eventType == .textDelta {
                continuation?.yield(
                    .streamChunk(
                        content: content,
                        messageId: messageId,
                        conversationId: conversationId
                    )
                )
            }
        }
        let accumulatedContent = responseMsg.content
        let receivedToolCalls = responseMsg.toolCalls

        let hasContent = !accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasToolCalls = receivedToolCalls != nil && !(receivedToolCalls?.isEmpty ?? true)

        var finalContent = accumulatedContent

        if !hasContent && hasToolCalls {
            let toolSummary = receivedToolCalls!.map { tc in
                "\(self.toolEmoji(for: tc.name)) \(tc.name)"
            }.joined(separator: "\n")

            let prefix = languagePreference == .chinese
                ? "正在执行 \(receivedToolCalls!.count) 个工具："
                : "Executing \(receivedToolCalls!.count) tools:"

            finalContent = prefix + "\n" + toolSummary
        }

        let finalMessage = ChatMessage(
            id: messageId,
            role: .assistant,
            content: finalContent,
            timestamp: Date(),
            toolCalls: receivedToolCalls,
            providerId: responseMsg.providerId,
            modelName: responseMsg.modelName,
            latency: responseMsg.latency,
            inputTokens: responseMsg.inputTokens,
            outputTokens: responseMsg.outputTokens,
            totalTokens: responseMsg.totalTokens,
            timeToFirstToken: responseMsg.timeToFirstToken,
            finishReason: responseMsg.finishReason,
            temperature: responseMsg.temperature,
            maxTokens: responseMsg.maxTokens
        )

        eventContinuation?.yield(.streamFinished(message: finalMessage, conversationId: conversationId))
        return finalMessage
    }

    // MARK: - 非流式响应处理

    private func processNonStreamingTurn(
        conversationId: UUID,
        config: LLMConfig,
        messages: [ChatMessage],
        availableTools: [AgentTool],
        languagePreference: LanguagePreference
    ) async throws -> ChatMessage {
        var responseMsg = try await llmService.sendMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        )

        let hasContent = !responseMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasToolCalls = responseMsg.toolCalls != nil && !(responseMsg.toolCalls?.isEmpty ?? true)

        if !hasContent && hasToolCalls {
            responseMsg = enhanceEmptyResponseWithToolSummary(responseMsg, languagePreference: languagePreference)
        }

        eventContinuation?.yield(.responseReceived(responseMsg, conversationId: conversationId))
        return responseMsg
    }

    private func enhanceEmptyResponseWithToolSummary(
        _ response: ChatMessage,
        languagePreference: LanguagePreference
    ) -> ChatMessage {
        guard let toolCalls = response.toolCalls else { return response }

        let toolSummary = toolCalls.map { tc in
            "\(toolEmoji(for: tc.name)) \(tc.name)"
        }.joined(separator: "\n")

        let prefix = languagePreference == .chinese
            ? "正在执行 \(toolCalls.count) 个工具："
            : "Executing \(toolCalls.count) tools:"

        let enhancedContent = prefix + "\n" + toolSummary

        return ChatMessage(
            id: response.id,
            role: response.role,
            content: enhancedContent,
            timestamp: response.timestamp,
            isError: response.isError,
            toolCalls: response.toolCalls,
            toolCallID: response.toolCallID
        )
    }

    // MARK: - 工具调用处理

    private func handleToolCall(
        _ toolCall: ToolCall,
        conversationId: UUID,
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        let requiresPermission = toolExecutionService.requiresPermission(
            toolName: toolCall.name,
            arguments: toolCall.arguments
        )

        if requiresPermission && !autoApproveRisk {
            let riskLevel = toolExecutionService.evaluateRisk(
                toolName: toolCall.name,
                arguments: toolCall.arguments
            )

            let permissionRequest = PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id,
                riskLevel: riskLevel
            )

            eventContinuation?.yield(.permissionRequested(permissionRequest, conversationId: conversationId))
            return
        }

        await executeToolAndContinue(
            toolCall,
            conversationId: conversationId,
            languagePreference: languagePreference
        )
    }

    func executeToolAndContinue(
        _ toolCall: ToolCall,
        conversationId: UUID,
        languagePreference: LanguagePreference
    ) async {
        do {
            let normalizedToolCall = normalizeToolCallForExecution(toolCall, conversationId: conversationId)
            let result = try await toolExecutionService.executeTool(normalizedToolCall)
            let trimmedResult = truncateToolResultIfNeeded(result)

            let resultMsg = ChatMessage(
                role: .user,
                content: trimmedResult,
                toolCallID: normalizedToolCall.id
            )

            eventContinuation?.yield(.toolResultReceived(resultMsg, conversationId: conversationId))
            await processPendingTools(conversationId: conversationId, languagePreference: languagePreference)
        } catch {
            let errorMsg = toolExecutionService.createErrorMessage(for: toolCall, error: error)
            eventContinuation?.yield(.toolResultReceived(errorMsg, conversationId: conversationId))
            await processPendingTools(conversationId: conversationId, languagePreference: languagePreference)
        }
    }

    private func processPendingTools(conversationId: UUID, languagePreference: LanguagePreference) async {
        var context = turnContexts[conversationId] ?? TurnContext()

        guard !context.pendingToolCalls.isEmpty else {
            eventContinuation?.yield(.shouldContinue(depth: context.currentDepth + 1, conversationId: conversationId))
            return
        }

        let nextTool = context.pendingToolCalls.removeFirst()
        turnContexts[conversationId] = context

        await handleToolCall(
            nextTool,
            conversationId: conversationId,
            languagePreference: languagePreference,
            autoApproveRisk: false
        )
    }

    private func emitAbortedToolResults(for toolCalls: [ToolCall], conversationId: UUID) {
        guard !toolCalls.isEmpty else { return }
        for toolCall in toolCalls {
            let abortMessage = ChatMessage(
                role: .user,
                content: "[Tool execution aborted by safety guard]",
                toolCallID: toolCall.id
            )
            eventContinuation?.yield(.toolResultReceived(abortMessage, conversationId: conversationId))
        }
    }

    private func normalizeToolCallForExecution(_ toolCall: ToolCall, conversationId: UUID) -> ToolCall {
        guard toolCall.name == createAndAssignTaskToolName,
              let providerId = turnContexts[conversationId]?.currentProviderId,
              !providerId.isEmpty else {
            return toolCall
        }

        guard let data = toolCall.arguments.data(using: .utf8),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return toolCall
        }

        // Worker provider is always aligned with current manager provider.
        json["providerId"] = providerId

        guard let normalizedData = try? JSONSerialization.data(withJSONObject: json),
              let normalizedArguments = String(data: normalizedData, encoding: .utf8) else {
            return toolCall
        }

        return ToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: normalizedArguments
        )
    }

    private func truncateToolResultIfNeeded(_ result: String) -> String {
        guard result.count > maxToolResultLength else { return result }
        let prefix = String(result.prefix(maxToolResultLength))
        return "\(prefix)\n\n... [Tool output truncated to \(maxToolResultLength) characters]"
    }

    // MARK: - 工具 Emoji

    private func toolEmoji(for toolName: String) -> String {
        switch toolName {
        case "read_file": return "📄"
        case "write_file": return "✏️"
        case "list_directory": return "📁"
        case "run_command": return "⚡"
        case createAndAssignTaskToolName: return "🧩"
        default: return "🔧"
        }
    }
}
