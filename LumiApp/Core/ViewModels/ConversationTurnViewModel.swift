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

        // 更新最后一个工具调用的参数
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

/// 对话轮次事件
/// 用于向外部报告对话轮次处理状态
@MainActor
enum ConversationTurnEvent: Sendable {
    /// 收到 LLM 响应
    case responseReceived(ChatMessage)
    /// 收到流式内容片段
    case streamChunk(content: String, messageId: UUID)
    /// 收到流式事件（包含事件类型和原始数据）
    case streamEvent(eventType: StreamEventType, content: String, rawEvent: String, messageId: UUID)
    /// 流式响应开始
    case streamStarted(messageId: UUID)
    /// 流式响应结束
    case streamFinished(message: ChatMessage)
    /// 收到工具执行结果
    case toolResultReceived(ChatMessage)
    /// 请求权限批准
    case permissionRequested(PermissionRequest)
    /// 达到最大递归深度
    case maxDepthReached(currentDepth: Int, maxDepth: Int)
    /// 轮次处理完成
    case completed
    /// 发生错误
    case error(Error)
    /// 应该继续下一轮
    case shouldContinue(depth: Int)
}

/// 对话轮次处理 ViewModel
/// 负责处理对话轮次流程控制，不直接执行工具，通过事件流报告状态
///
/// ## 设计原则
///
/// `ConversationTurnViewModel` 只负责对话轮次的流程控制：
/// 1. 调用 LLM 获取响应
/// 2. 检查是否需要工具调用
/// 3. 通过事件流通知外部处理工具执行
/// 4. 管理递归深度和轮次状态
///
/// 具体的工具执行由外部（如 AgentProvider）通过订阅事件流来处理。
///
/// ## 使用示例
///
/// ```swift
/// // 订阅事件流
/// for await event in conversationTurnViewModel.events {
///     switch event {
///     case .responseReceived(let message):
///         // 保存消息到列表
///     case .permissionRequested(let request):
///         // 显示权限请求 UI
///     case .toolResultReceived(let result):
///         // 处理工具结果
///     case .shouldContinue(let depth):
///         // 继续下一轮
///         await processTurn(depth: depth)
///     case .completed:
///         // 轮次完成
///     case .error(let error):
///         // 处理错误
///     }
/// }
/// ```
@MainActor
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    // MARK: - 事件流

    /// 对话轮次事件流
    var events: AsyncStream<ConversationTurnEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    /// 事件流延续
    private var eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation?

    // MARK: - 服务依赖

    /// LLM 服务
    private let llmService: LLMService

    /// 工具执行服务
    private let toolExecutionService: ToolExecutionService

    /// 提示词服务
    private let promptService: PromptService

    // MARK: - 处理状态

    /// 当前递归深度
    private var currentDepth: Int = 0

    /// 待处理工具调用队列
    private var pendingToolCalls: [ToolCall] = []

    /// 最大递归深度
    private let maxDepth = 100

    // MARK: - 初始化

    /// 初始化对话轮次 ViewModel
    /// - Parameters:
    ///   - llmService: LLM 服务
    ///   - toolExecutionService: 工具执行服务
    ///   - promptService: 提示词服务
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

    /// 是否启用流式响应
    var enableStreaming: Bool = true

    /// 处理对话轮次
    ///
    /// - Parameters:
    ///   - depth: 当前递归深度
    ///   - config: LLM 配置
    ///   - messages: 当前消息列表
    ///   - chatMode: 聊天模式
    ///   - tools: 可用工具列表
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    func processTurn(
        depth: Int = 0,
        config: LLMConfig,
        messages: [ChatMessage],
        chatMode: ChatMode,
        tools: [AgentTool],
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        guard depth < maxDepth else {
            eventContinuation?.yield(.maxDepthReached(currentDepth: depth, maxDepth: maxDepth))
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(Self.t)🚀 开始处理对话轮次 (深度：\(depth), 模式：\(chatMode.displayName), 流式：\(self.enableStreaming))")
        }

        // 根据聊天模式决定是否传递工具
        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        if Self.verbose && chatMode == .chat {
            os_log("\(Self.t) 当前为对话模式，不传递工具")
        }

        do {
            let responseMsg: ChatMessage

            if enableStreaming {
                // 使用流式响应
                responseMsg = try await processStreamingTurn(
                    config: config,
                    messages: messages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            } else {
                // 使用非流式响应
                responseMsg = try await processNonStreamingTurn(
                    config: config,
                    messages: messages,
                    availableTools: availableTools,
                    languagePreference: languagePreference
                )
            }

            // 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(Self.t)🔧 收到 \(toolCalls.count) 个工具调用，开始处理")
                }
                pendingToolCalls = toolCalls

                // 处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(
                    firstTool,
                    languagePreference: languagePreference,
                    autoApproveRisk: autoApproveRisk
                )
            } else {
                // 无工具调用，轮次结束
                eventContinuation?.yield(.completed)
                if Self.verbose {
                    os_log("\(Self.t)✅ 对话轮次已完成（无工具调用）")
                }
            }
        } catch {
            // 错误发生时清空待处理工具队列
            pendingToolCalls.removeAll()
            eventContinuation?.yield(.error(error))
            os_log(.error, "\(Self.t) 对话处理失败")
        }
    }

    // MARK: - 流式响应处理

    /// 处理流式对话轮次
    private func processStreamingTurn(
        config: LLMConfig,
        messages: [ChatMessage],
        availableTools: [AgentTool],
        languagePreference: LanguagePreference
    ) async throws -> ChatMessage {
        // 生成消息ID用于流式更新
        let messageId = UUID()

        // 通知流式响应开始
        eventContinuation?.yield(.streamStarted(messageId: messageId))

        // 累积内容 - 使用 actor 隔离的变量
        let streamState = StreamState()

        // 发送流式请求
        let responseMsg = try await llmService.sendStreamingMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        ) { [weak self] chunk in
            guard let self = self else { return }

            Task { @MainActor in
                // 处理所有事件类型，发送 streamEvent
                if let eventType = chunk.eventType {
                    // 对于 inputJsonDelta，使用 partialJson 作为内容
                    let content: String
                    if eventType == .inputJsonDelta {
                        content = chunk.partialJson ?? ""
                    } else {
                        content = chunk.content ?? ""
                    }
                    let rawEvent = chunk.rawEvent ?? ""
                    self.eventContinuation?.yield(.streamEvent(
                        eventType: eventType,
                        content: content,
                        rawEvent: rawEvent,
                        messageId: messageId
                    ))
                }

                // 处理内容片段（用于累积）- 只处理 textDelta，跳过 thinkingDelta
                if let content = chunk.content, chunk.eventType == .textDelta {
                    await streamState.appendContent(content)
                    // 通知外部收到内容片段
                    self.eventContinuation?.yield(.streamChunk(content: content, messageId: messageId))
                }

                // 处理工具调用参数分片
                if let partialJson = chunk.partialJson {
                    await streamState.appendToolCallArguments(partialJson)
                }

                // 处理工具调用
                if let toolCalls = chunk.toolCalls {
                    await streamState.setToolCalls(toolCalls)
                }
            }
        }

        // 更新工具调用参数
        await streamState.updateToolCallsWithArguments()

        // 获取累积的内容和工具调用
        let accumulatedContent = await streamState.getContent()
        let receivedToolCalls = await streamState.getToolCalls()

        // 检查内容是否为空但有工具调用
        let hasContent = !accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasToolCalls = receivedToolCalls != nil && !receivedToolCalls!.isEmpty

        var finalContent = accumulatedContent

        // 当无内容但有工具调用时，生成一个友好的提示消息
        if !hasContent && hasToolCalls {
            let toolSummary = receivedToolCalls!.enumerated().map { index, tc in
                let emoji = self.toolEmoji(for: tc.name)
                return "\(emoji) \(tc.name)"
            }.joined(separator: "\n")

            let prefix = languagePreference == .chinese
                ? "正在执行 \(receivedToolCalls!.count) 个工具："
                : "Executing \(receivedToolCalls!.count) tools:"

            finalContent = prefix + "\n" + toolSummary
        }

        // 构建最终消息
        let finalMessage = ChatMessage(
            id: messageId,
            role: .assistant,
            content: finalContent,
            timestamp: Date(),
            toolCalls: receivedToolCalls,
            providerId: responseMsg.providerId,
            modelName: responseMsg.modelName,
            latency: responseMsg.latency
        )

        // 通知流式响应结束
        eventContinuation?.yield(.streamFinished(message: finalMessage))

        return finalMessage
    }

    // MARK: - 非流式响应处理

    /// 处理非流式对话轮次
    private func processNonStreamingTurn(
        config: LLMConfig,
        messages: [ChatMessage],
        availableTools: [AgentTool],
        languagePreference: LanguagePreference
    ) async throws -> ChatMessage {
        // 获取 LLM 响应
        var responseMsg = try await llmService.sendMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        )

        // 检查内容是否为空（只有空白字符）
        let hasContent = !responseMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasToolCalls = responseMsg.toolCalls != nil && !responseMsg.toolCalls!.isEmpty

        // 当无内容但有工具调用时，生成一个友好的提示消息
        if !hasContent && hasToolCalls {
            responseMsg = enhanceEmptyResponseWithToolSummary(
                responseMsg,
                languagePreference: languagePreference
            )
        }

        // 通知外部收到响应
        eventContinuation?.yield(.responseReceived(responseMsg))

        return responseMsg
    }

    /// 增强空响应（添加工具摘要）
    private func enhanceEmptyResponseWithToolSummary(
        _ response: ChatMessage,
        languagePreference: LanguagePreference
    ) -> ChatMessage {
        guard let toolCalls = response.toolCalls else { return response }

        let toolSummary = toolCalls.enumerated().map { index, tc in
            let emoji = toolEmoji(for: tc.name)
            return "\(emoji) \(tc.name)"
        }.joined(separator: "\n")

        let prefix = languagePreference == .chinese
            ? "正在执行 \(toolCalls.count) 个工具："
            : "Executing \(toolCalls.count) tools:"

        let enhancedContent = prefix + "\n" + toolSummary

        if Self.verbose {
            os_log("\(Self.t)📝 为空内容消息生成工具摘要")
        }

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

    /// 处理工具调用
    ///
    /// 检查权限，如果需要则请求批准，否则直接执行
    private func handleToolCall(
        _ toolCall: ToolCall,
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        let requiresPermission = toolExecutionService.requiresPermission(
            toolName: toolCall.name,
            arguments: toolCall.arguments
        )

        if requiresPermission && !autoApproveRisk {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 工具 \(toolCall.name) 需要权限批准")
            }

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

            // 通知外部请求权限
            eventContinuation?.yield(.permissionRequested(permissionRequest))
            return
        }

        // 无需权限，直接执行
        await executeToolAndContinue(toolCall, languagePreference: languagePreference)
    }

    /// 执行工具并继续处理队列
    /// - Parameter toolCall: 工具调用
    func executeToolAndContinue(
        _ toolCall: ToolCall,
        languagePreference: LanguagePreference
    ) async {
        do {
            let result = try await toolExecutionService.executeTool(toolCall)

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
            )

            // 通知外部收到工具结果
            eventContinuation?.yield(.toolResultReceived(resultMsg))

            // 继续处理待处理工具
            await processPendingTools(languagePreference: languagePreference)
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")

            let errorMsg = toolExecutionService.createErrorMessage(for: toolCall, error: error)
            eventContinuation?.yield(.toolResultReceived(errorMsg))
            await processPendingTools(languagePreference: languagePreference)
        }
    }

    /// 处理待处理工具队列
    private func processPendingTools(languagePreference: LanguagePreference) async {
        guard !pendingToolCalls.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)✅ 所有工具处理完成，继续对话")
            }
            // 通知外部继续下一轮
            eventContinuation?.yield(.shouldContinue(depth: currentDepth + 1))
            return
        }

        let nextTool = pendingToolCalls.removeFirst()

        if Self.verbose {
            os_log("\(Self.t)🔧 处理下一个工具：\(nextTool.name)，剩余 \(self.pendingToolCalls.count) 个")
        }

        // 注意：这里不直接执行，而是通知外部
        // 外部应该调用 processTurn 或 handleToolCall 继续处理
        // 但为了保持流程，我们直接处理
        await handleToolCall(
            nextTool,
            languagePreference: languagePreference,
            autoApproveRisk: false // 后续工具默认不自动批准
        )
    }

    // MARK: - 工具 Emoji

    /// 获取工具对应的 Emoji
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
