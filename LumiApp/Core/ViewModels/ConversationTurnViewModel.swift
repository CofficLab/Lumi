import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 流式状态管理 Actor
/// 用于在并发环境中安全地累积流式响应内容
@MainActor
final class StreamState: Sendable {
    private var content: String = ""
    private var toolCalls: [ToolCall]?
    private var currentToolCallArguments: String = ""

    func appendContent(_ newContent: String) {
        content += newContent
    }

    func setToolCalls(_ calls: [ToolCall]) {
        toolCalls = calls
        currentToolCallArguments = ""
    }

    func appendToolCallArguments(_ partialJson: String) {
        currentToolCallArguments += partialJson
    }

    func updateToolCallsWithArguments() {
        guard !currentToolCallArguments.isEmpty,
              let calls = toolCalls,
              let lastCall = calls.last else { return }

        let updatedCall = ToolCall(
            id: lastCall.id,
            name: lastCall.name,
            arguments: currentToolCallArguments
        )
        var updatedCalls = calls
        updatedCalls[updatedCalls.count - 1] = updatedCall
        toolCalls = updatedCalls
    }

    func getContent() -> String {
        content
    }

    func getToolCalls() -> [ToolCall]? {
        toolCalls
    }
}

@MainActor
private struct TurnContext {
    var currentDepth: Int = 0
    var pendingToolCalls: [ToolCall] = []
}

/// 对话轮次事件
@MainActor
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
    private let maxDepth = 100

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
        guard depth < maxDepth else {
            eventContinuation?.yield(.maxDepthReached(currentDepth: depth, maxDepth: maxDepth, conversationId: conversationId))
            return
        }

        var context = turnContexts[conversationId] ?? TurnContext()
        context.currentDepth = depth
        turnContexts[conversationId] = context

        if Self.verbose {
            os_log("\(Self.t)🚀 [\(conversationId)] 开始处理轮次 (深度：\(depth), 模式：\(chatMode.displayName), 流式：\(self.enableStreaming))")
        }

        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        do {
            let responseMsg: ChatMessage

            if enableStreaming {
                responseMsg = try await processStreamingTurn(
                    conversationId: conversationId,
                    config: config,
                    messages: messages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            } else {
                responseMsg = try await processNonStreamingTurn(
                    conversationId: conversationId,
                    config: config,
                    messages: messages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            }

            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(Self.t)🔧 [\(conversationId)] 收到 \(toolCalls.count) 个工具调用")
                }

                context = turnContexts[conversationId] ?? TurnContext()
                context.pendingToolCalls = toolCalls
                turnContexts[conversationId] = context

                let firstTool = context.pendingToolCalls.removeFirst()
                turnContexts[conversationId] = context

                await handleToolCall(
                    firstTool,
                    conversationId: conversationId,
                    languagePreference: languagePreference,
                    autoApproveRisk: autoApproveRisk
                )
            } else {
                eventContinuation?.yield(.completed(conversationId: conversationId))
                if Self.verbose {
                    os_log("\(Self.t)✅ [\(conversationId)] 轮次完成（无工具）")
                }
            }
        } catch {
            var failedContext = turnContexts[conversationId] ?? TurnContext()
            failedContext.pendingToolCalls.removeAll()
            turnContexts[conversationId] = failedContext

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

        let streamState = StreamState()

        let responseMsg = try await llmService.sendStreamingMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        ) { [weak self] chunk in
            guard let self = self else { return }

            Task { @MainActor in
                if let eventType = chunk.eventType {
                    let content: String = (eventType == .inputJsonDelta) ? (chunk.partialJson ?? "") : (chunk.content ?? "")
                    let rawEvent = chunk.rawEvent ?? ""
                    self.eventContinuation?.yield(.streamEvent(
                        eventType: eventType,
                        content: content,
                        rawEvent: rawEvent,
                        messageId: messageId,
                        conversationId: conversationId
                    ))
                }

                if let content = chunk.content, chunk.eventType == .textDelta {
                    streamState.appendContent(content)
                    self.eventContinuation?.yield(.streamChunk(content: content, messageId: messageId, conversationId: conversationId))
                }

                if let partialJson = chunk.partialJson {
                    streamState.appendToolCallArguments(partialJson)
                }

                if let toolCalls = chunk.toolCalls {
                    streamState.setToolCalls(toolCalls)
                }
            }
        }

        streamState.updateToolCallsWithArguments()

        let accumulatedContent = streamState.getContent()
        let receivedToolCalls = streamState.getToolCalls()

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
            let result = try await toolExecutionService.executeTool(toolCall)

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
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

    // MARK: - 工具 Emoji

    private func toolEmoji(for toolName: String) -> String {
        switch toolName {
        case "read_file": return "📄"
        case "write_file": return "✏️"
        case "list_directory": return "📁"
        case "run_command": return "⚡"
        default: return "🔧"
        }
    }
}
