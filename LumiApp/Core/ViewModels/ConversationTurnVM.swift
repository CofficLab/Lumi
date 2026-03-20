import Combine
import Foundation
import MagicKit
import SwiftUI

/// 对话轮次处理 ViewModel（含轮次任务队列、流水线构建与流式 flush；由 `RootView.task` 挂接事件消费）。
@MainActor
final class ConversationTurnVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    // MARK: - 事件流（单消费者；勿多处 for-await，否则后续订阅会覆盖 continuation）

    let events: AsyncStream<ConversationTurnEvent>
    private let eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation

    // MARK: - 服务依赖

    private let llmService: LLMService
    private let toolExecutionService: ToolExecutionService

    /// 供工具栏等读取快捷短语（`PromptService` 为 actor，经引用同步调用其非隔离方法）。
    let promptService: PromptService
    let toolService: ToolService

    let runtimeStore: ConversationRuntimeStore
    let sessionConfig: AgentSessionConfig
    let chatHistoryService: ChatHistoryService
    let messageViewModel: MessagePendingVM
    let ConversationVM: ConversationVM
    let messageSenderVM: MessageQueueVM
    let projectVM: ProjectVM

    private let processingStateViewModel: ProcessingStateVM
    private let permissionRequestViewModel: PermissionRequestVM
    private let thinkingStateViewModel: ThinkingStateVM
    private let depthWarningViewModel: DepthWarningVM

    private var pipelineCancellables = Set<AnyCancellable>()
    private var turnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    private var turnTaskGenerationByConversation: [UUID: Int] = [:]
    private let maxThinkingTextLength = 100000
    private let streamUIFlushInterval: TimeInterval = 0.08
    private let thinkingUIFlushInterval: TimeInterval = 0.12
    private let immediateStreamFlushChars = 80
    private let immediateThinkingFlushChars = 120
    private let captureThinkingContent = true

    // MARK: - 会话上下文

    // 轮次控制上下文已迁移到 `ConversationRuntimeStore.turnContextsByConversation`
    private let maxDepth = 60
    private let maxToolResultLength = 4000

    /// 连续重复同一工具签名（名称+参数）达到多少次视为循环
    private let repeatedToolSignatureThreshold = 10

    /// 在最近窗口中同一签名出现多少次视为循环
    private let repeatedToolWindowThreshold = 10

    /// 仅转发必要的流式事件；thinkingDelta 需转发以便 ThinkingDeltaCaptureMiddleware 写入 runtimeStore，供落库时写入 thinkingContent。
    private nonisolated static func shouldForwardStreamEvent(_ eventType: StreamEventType) -> Bool {
        switch eventType {
        case .ping, .contentBlockStart, .contentBlockStop, .messageDelta, .signatureDelta, .thinkingDelta:
            return true
        case .messageStart, .messageStop, .unknown, .contentBlockDelta, .inputJsonDelta, .textDelta:
            return false
        }
    }

    // MARK: - 初始化

    init(
        llmService: LLMService,
        toolExecutionService: ToolExecutionService,
        promptService: PromptService,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        chatHistoryService: ChatHistoryService,
        toolService: ToolService,
        messageViewModel: MessagePendingVM,
        ConversationVM: ConversationVM,
        messageSenderVM: MessageQueueVM,
        projectVM: ProjectVM,
        processingStateViewModel: ProcessingStateVM,
        permissionRequestViewModel: PermissionRequestVM,
        thinkingStateViewModel: ThinkingStateVM,
        depthWarningViewModel: DepthWarningVM
    ) {
        var continuation: AsyncStream<ConversationTurnEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation

        self.llmService = llmService
        self.toolExecutionService = toolExecutionService
        self.promptService = promptService
        self.toolService = toolService
        self.runtimeStore = runtimeStore
        self.sessionConfig = sessionConfig
        self.chatHistoryService = chatHistoryService
        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.messageSenderVM = messageSenderVM
        self.projectVM = projectVM
        self.processingStateViewModel = processingStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.thinkingStateViewModel = thinkingStateViewModel
        self.depthWarningViewModel = depthWarningViewModel

        runtimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &pipelineCancellables)
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
        let depthGuardResult = MaxDepthReachedGuard().evaluate(depth: depth, maxDepth: maxDepth)

        switch depthGuardResult {
        case let .reached(currentDepth, maxDepth):
            eventContinuation.yield(.maxDepthReached(currentDepth: currentDepth, maxDepth: maxDepth, conversationId: conversationId))
            return
        case let .proceed(isFinalStep):
            break
        }

        let isFinalStep: Bool = {
            if case let .proceed(final) = depthGuardResult { return final }
            return false
        }()

        var context = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
        if depth == 0 {
            context = ConversationTurnContext()
            context.chainStartedAt = Date()
        }
        if context.chainStartedAt == nil {
            context.chainStartedAt = Date()
        }
        context.currentDepth = depth
        context.currentProviderId = config.providerId
        runtimeStore.turnContextsByConversation[conversationId] = context

        if Self.verbose {
            AppLogger.core.info("\(self.t)[\(conversationId)] 开始处理轮次 (深度：\(depth), 模式：\(chatMode.displayName), 流式：\(self.enableStreaming))")
        }

        let availableTools: [AgentTool] = (chatMode.allowsTools && !isFinalStep) ? tools : []

        var effectiveMessages = messages
        if isFinalStep {
            effectiveMessages.append(ChatMessage.maxDepthFinalStepReminderMessage())
        }

        if await llmService.needsLocalModelLoad(config: config) {
            let loadingMessage = ChatMessage.loadingLocalModelSystemMessage(
                languagePreference: languagePreference,
                providerId: config.providerId,
                modelName: config.model
            )
            eventContinuation.yield(.responseReceived(loadingMessage, conversationId: conversationId))
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

            context = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
            let consecutiveEmptyLoopResult = ConsecutiveEmptyToolTurnsLoopGuard().evaluate(
                hasToolCalls: hasToolCalls,
                hasContent: hasContent,
                context: &context,
                threshold: 3
            )
            runtimeStore.turnContextsByConversation[conversationId] = context

            // 防止模型陷入“空文本 + 工具调用”循环，导致长时间卡住。
            if case let .abort(error) = consecutiveEmptyLoopResult {
                if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                }
                context.pendingToolCalls.removeAll()
                runtimeStore.turnContextsByConversation[conversationId] = context
                eventContinuation.yield(.error(error, conversationId: conversationId))
                AppLogger.core.error("\(self.t)[\(conversationId)] 连续空响应工具循环，已中止")
                return
            }

            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if isFinalStep {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                    var broken = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
                    broken.pendingToolCalls.removeAll()
                    runtimeStore.turnContextsByConversation[conversationId] = broken
                    // 在 UI 中给出明确的助手提示，而不是静默结束
                    let explainMessage = ChatMessage.maxDepthToolLimitMessage(
                        languagePreference: languagePreference,
                        currentDepth: depth,
                        maxDepth: maxDepth
                    )
                    eventContinuation.yield(.responseReceived(explainMessage, conversationId: conversationId))
                    eventContinuation.yield(.completed(conversationId: conversationId))
                    if Self.verbose {
                        AppLogger.core.warning("\(self.t)[\(conversationId)] 最后一步仍请求工具，已忽略并结束本轮")
                    }
                    return
                }

                if Self.verbose {
                    AppLogger.core.info("\(self.t)[\(conversationId)] 收到 \(toolCalls.count) 个工具调用")
                }

                context = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
                context.pendingToolCalls = toolCalls
                runtimeStore.turnContextsByConversation[conversationId] = context

                let firstTool = context.pendingToolCalls.removeFirst()

                // 检测重复工具循环（同名 + 同参数）
                let guardResult = RepeatedToolSignatureLoopGuard().evaluate(
                    firstTool: firstTool,
                    toolCalls: toolCalls,
                    languagePreference: languagePreference,
                    context: &context,
                    config: .init(
                        repeatedToolSignatureThreshold: repeatedToolSignatureThreshold,
                        repeatedToolWindowThreshold: repeatedToolWindowThreshold,
                        recentWindowMaxCount: 6,
                        signatureArgsPrefixLength: 512
                    )
                )

                runtimeStore.turnContextsByConversation[conversationId] = context

                if case let .abort(message, error) = guardResult {
                    emitAbortedToolResults(for: toolCalls, conversationId: conversationId)
                    eventContinuation.yield(.responseReceived(message, conversationId: conversationId))
                    eventContinuation.yield(.error(error, conversationId: conversationId))
                    AppLogger.core.error("\(self.t)[\(conversationId)] 重复工具调用循环，已中止: \(firstTool.name)")
                    return
                }

                await handleToolCall(
                    firstTool,
                    conversationId: conversationId,
                    languagePreference: languagePreference,
                    autoApproveRisk: autoApproveRisk
                )
            } else {
                context = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
                context.lastToolSignature = nil
                context.repeatedToolSignatureCount = 0
                context.recentToolSignatures.removeAll(keepingCapacity: false)
                runtimeStore.turnContextsByConversation[conversationId] = context
                eventContinuation.yield(.completed(conversationId: conversationId))
                if Self.verbose {
                    AppLogger.core.info("\(self.t)[\(conversationId)] 轮次完成（无工具）")
                }
            }
        } catch {
            var failedContext = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()
            failedContext.pendingToolCalls.removeAll()
            runtimeStore.turnContextsByConversation[conversationId] = failedContext

            // 针对 API Key 为空的配置错误，使用专门的 system 消息，并在 UI 中渲染内嵌的 API Key 配置视图
            if let configError = error as? LLMConfigValidationError,
               case .apiKeyEmpty = configError {
                let explainMessage = ChatMessage.apiKeyMissingSystemMessage(languagePreference: languagePreference)
                eventContinuation.yield(.responseReceived(explainMessage, conversationId: conversationId))
                eventContinuation.yield(.error(error, conversationId: conversationId))
                AppLogger.core.error("\(self.t)[\(conversationId)] 配置校验失败：API Key 为空")
            } else {
                let explainMessage = ChatMessage.requestFailedMessage(languagePreference: languagePreference, error: error)
                eventContinuation.yield(.responseReceived(explainMessage, conversationId: conversationId))
                eventContinuation.yield(.error(error, conversationId: conversationId))
                AppLogger.core.error("\(self.t)[\(conversationId)] 对话处理失败：\(error.localizedDescription)")
            }
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
        eventContinuation.yield(.streamStarted(messageId: messageId, conversationId: conversationId))
        let streamContinuation = eventContinuation

        let responseMsg = try await llmService.sendStreamingMessage(
            messages: messages,
            config: config,
            tools: availableTools.isEmpty ? nil : availableTools
        ) { chunk in
            if let eventType = chunk.eventType {
                if Self.shouldForwardStreamEvent(eventType) {
                    let content: String = (eventType == .inputJsonDelta) ? (chunk.partialJson ?? "") : (chunk.content ?? "")
                    let rawEvent = chunk.rawEvent ?? ""
                    streamContinuation.yield(
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
                streamContinuation.yield(
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

        var finalContent = accumulatedContent

        // “空 content + toolCalls” 的展示增强已迁移到中间件：`EmptyToolResponseContentMiddleware`。

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

        eventContinuation.yield(.streamFinished(message: finalMessage, conversationId: conversationId))
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

        // “空 content + toolCalls” 的展示增强已迁移到中间件：`EmptyToolResponseContentMiddleware`。

        eventContinuation.yield(.responseReceived(responseMsg, conversationId: conversationId))
        return responseMsg
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

            eventContinuation.yield(.permissionRequested(permissionRequest, conversationId: conversationId))
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
                role: .tool,
                content: result,
                toolCallID: toolCall.id
            )

            eventContinuation.yield(.toolResultReceived(resultMsg, conversationId: conversationId))
            await processPendingTools(conversationId: conversationId, languagePreference: languagePreference)
        } catch {
            let errorMsg = toolExecutionService.createErrorMessage(for: toolCall, error: error)
            eventContinuation.yield(.toolResultReceived(errorMsg, conversationId: conversationId))
            await processPendingTools(conversationId: conversationId, languagePreference: languagePreference)
        }
    }

    func emitPermissionDecision(
        allowed: Bool,
        request: PermissionRequest,
        conversationId: UUID
    ) {
        eventContinuation.yield(
            .permissionDecision(
                allowed: allowed,
                request: request,
                conversationId: conversationId
            )
        )
    }

    private func processPendingTools(conversationId: UUID, languagePreference: LanguagePreference) async {
        var context = runtimeStore.turnContextsByConversation[conversationId] ?? ConversationTurnContext()

        guard !context.pendingToolCalls.isEmpty else {
            eventContinuation.yield(.shouldContinue(depth: context.currentDepth + 1, conversationId: conversationId))
            return
        }

        let nextTool = context.pendingToolCalls.removeFirst()
        runtimeStore.turnContextsByConversation[conversationId] = context

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
                role: .tool,
                content: "[Tool execution aborted by safety guard]",
                toolCallID: toolCall.id
            )
            eventContinuation.yield(.toolResultReceived(abortMessage, conversationId: conversationId))
        }
    }

    // MARK: - 轮次流水线编排

    func makeConversationTurnPipelineHandler() -> ConversationTurnPipelineHandler {
        ConversationTurnPipelineHandler(
            conversationTurnViewModel: self,
            runtimeStore: runtimeStore,
            env: .init(
                selectedConversationId: { [weak self] in self?.ConversationVM.selectedConversationId },
                languagePreference: { [weak self] in self?.projectVM.languagePreference ?? .chinese },
                maxDepth: maxDepth,
                maxThinkingTextLength: maxThinkingTextLength,
                maxToolResultLength: maxToolResultLength,
                immediateStreamFlushChars: immediateStreamFlushChars,
                immediateThinkingFlushChars: immediateThinkingFlushChars,
                streamUIFlushInterval: streamUIFlushInterval,
                thinkingUIFlushInterval: thinkingUIFlushInterval,
                captureThinkingContent: captureThinkingContent
            ),
            messages: .init(
                messages: { [weak self] in self?.messageViewModel.messages ?? [] },
                appendMessage: { [weak self] m in self?.messageViewModel.appendMessage(m) },
                updateMessage: { [weak self] m, idx in self?.messageViewModel.updateMessage(m, at: idx) },
                saveMessage: { [weak self] m, cid in
                    guard let self else { return }
                    await self.ConversationVM.saveMessage(m, to: cid)
                },
                enqueueTurnProcessing: { [weak self] cid, depth in
                    self?.enqueueTurnProcessing(conversationId: cid, depth: depth)
                },
                executeToolAndContinue: { [weak self] toolCall, cid, languagePreference in
                    guard let self else { return }
                    await self.executeToolAndContinue(toolCall, conversationId: cid, languagePreference: languagePreference)
                },
                updateRuntimeState: { [weak self] cid in
                    self?.updateRuntimeState(for: cid)
                }
            ),
            ui: conversationTurnPipelineUIActions(),
            onFallbackEvent: { [weak self] event in
                guard let self else { return }
                await self.handleConversationTurnEventFallback(event)
            }
        )
    }

    private func conversationTurnPipelineUIActions() -> ConversationTurnMiddlewareUIActions {
        let processing = processingStateViewModel
        let permission = permissionRequestViewModel
        let thinking = thinkingStateViewModel
        let depth = depthWarningViewModel
        return .init(
            setPendingPermissionRequest: { request, _ in
                permission.setPendingPermissionRequest(request)
            },
            setDepthWarning: { warning, _ in
                depth.setDepthWarning(warning)
            },
            onTurnFinishedUI: { _ in
                processing.finish()
            },
            onTurnFailedUI: { _, _ in
                processing.finish()
            },
            onStreamStartedUI: { [weak self] _, conversationId in
                guard let self else { return }
                processing.markStreamStarted()
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.runtimeStore.bumpStreamingPresentation()
                }
            },
            onStreamFirstTokenUI: { _, ttftMs in
                if let ttftMs {
                    processing.markFirstToken(ttftMs: ttftMs)
                } else {
                    processing.markGenerating()
                }
            },
            onStreamFinishedUI: { [weak self] conversationId in
                guard let self else { return }
                thinking.setThinkingText(
                    self.runtimeStore.thinkingTextByConversation[conversationId] ?? "",
                    for: conversationId
                )
                thinking.setIsThinking(false, for: conversationId)
                processing.finish()
                self.runtimeStore.streamingTextByConversation[conversationId] = nil
                if self.ConversationVM.selectedConversationId == conversationId {
                    self.runtimeStore.bumpStreamingPresentation()
                }
            },
            onThinkingStartedUI: { conversationId in
                thinking.setIsThinking(true, for: conversationId)
            },
            setLastHeartbeatTime: { date in
                processing.setLastHeartbeatTime(date)
            },
            setIsThinking: { isThinking, cid in
                thinking.setIsThinking(isThinking, for: cid)
            },
            setThinkingText: { text, cid in
                thinking.setThinkingText(text, for: cid)
            },
            appendThinkingText: { text, cid in
                thinking.appendThinkingText(text, for: cid)
            }
        )
    }

    /// 取消任务后重置与轮次相关的 UI VM（权限气泡、处理中、思考态）。
    func resetUIAfterAgentCancel(for conversationId: UUID) {
        processingStateViewModel.setIsProcessing(false)
        thinkingStateViewModel.setIsThinking(false, for: conversationId)
        permissionRequestViewModel.setPendingPermissionRequest(nil)
    }

    private func handleConversationTurnEventFallback(_ event: ConversationTurnEvent) async {
        switch event {
        default:
            break
        }
    }

    func enqueueTurnProcessing(conversationId: UUID, depth: Int) {
        let previousTask: Task<Void, Never>?
        if depth == 0 {
            if Self.verbose, turnTaskPipelineByConversation[conversationId] != nil {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 新消息到达，取消旧轮次链路")
            }
            turnTaskPipelineByConversation[conversationId]?.cancel()
            turnTaskPipelineByConversation[conversationId] = nil
            previousTask = nil
        } else {
            previousTask = turnTaskPipelineByConversation[conversationId]
        }
        let generation = (turnTaskGenerationByConversation[conversationId] ?? 0) + 1
        turnTaskGenerationByConversation[conversationId] = generation
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 轮次入队 depth=\(depth), gen=\(generation)")
        }

        let task = Task { [weak self] in
            if let previousTask {
                await previousTask.value
            }
            guard let self else { return }
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId)] 开始执行轮次 depth=\(depth), gen=\(generation)")
            }
            await self.runTurnJob(conversationId: conversationId, depth: depth)

            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.turnTaskGenerationByConversation[conversationId] == generation {
                    self.turnTaskPipelineByConversation[conversationId] = nil
                }
            }
        }

        turnTaskPipelineByConversation[conversationId] = task
    }

    func updateRuntimeState(for conversationId: UUID) {
        runtimeStore.updateRuntimeState(for: conversationId)
    }

    func appendPipelineMessage(_ message: ChatMessage) {
        messageViewModel.appendMessage(message)
    }

    func cancelTurnPipeline(for conversationId: UUID) {
        turnTaskPipelineByConversation[conversationId]?.cancel()
        turnTaskPipelineByConversation[conversationId] = nil
    }

    private func runTurnJob(conversationId: UUID, depth: Int) async {
        let messages = await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []

        await processTurn(
            conversationId: conversationId,
            depth: depth,
            config: sessionConfig.getCurrentConfig(),
            messages: messages,
            chatMode: projectVM.chatMode,
            tools: toolService.tools,
            languagePreference: projectVM.languagePreference,
            autoApproveRisk: projectVM.autoApproveRisk
        )
    }
}
