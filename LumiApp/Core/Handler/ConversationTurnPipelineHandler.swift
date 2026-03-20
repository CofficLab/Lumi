import Foundation
import MagicKit

/// 负责轮次执行的 handler：内部拥有事件源（AsyncStream），并消费 ConversationTurnPipeline 的中间件链。
///
/// RootView 只需要启动 `run()`；轮次推进由 middlewares 触发的 `enqueueTurnProcessing` 驱动。
@MainActor
final class ConversationTurnPipelineHandler: SuperLog {
    nonisolated static let emoji = "🔁"
    nonisolated static let verbose = false

    // MARK: - 事件源（单消费者；勿多处 for-await）

    let events: AsyncStream<ConversationTurnEvent>
    private let eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation

    // MARK: - 服务依赖

    private let llmService: LLMService
    private let toolExecutionService: ToolExecutionService
    private let runtimeStore: ConversationRuntimeStore
    private let sessionConfig: AgentSessionConfig
    private let chatHistoryService: ChatHistoryService
    private let toolService: ToolService

    // MARK: - UI/投影依赖（通过 middlewares 动作闭包完成刷新与落库）

    private let messageViewModel: MessagePendingVM
    private let ConversationVM: ConversationVM
    private let projectVM: ProjectVM

    private let processingStateViewModel: ProcessingStateVM
    private let permissionRequestViewModel: PermissionRequestVM
    private let thinkingStateViewModel: ThinkingStateVM
    private let depthWarningViewModel: DepthWarningVM

    private let captureThinkingContent: Bool

    // MARK: - Middleware 上下文

    private lazy var env: ConversationTurnMiddlewareEnvironment = { [weak self] in
        guard let self else {
            return .init(
                selectedConversationId: { nil },
                languagePreference: { .chinese },
                maxDepth: AgentConfig.maxDepth,
                maxThinkingTextLength: AgentConfig.maxThinkingTextLength,
                maxToolResultLength: AgentConfig.maxToolResultLength,
                immediateStreamFlushChars: AgentConfig.immediateStreamFlushChars,
                immediateThinkingFlushChars: AgentConfig.immediateThinkingFlushChars,
                streamUIFlushInterval: AgentConfig.streamUIFlushInterval,
                thinkingUIFlushInterval: AgentConfig.thinkingUIFlushInterval,
                captureThinkingContent: self?.captureThinkingContent ?? true
            )
        }
        return .init(
            selectedConversationId: { [weak self] in self?.ConversationVM.selectedConversationId },
            languagePreference: { [weak self] in self?.projectVM.languagePreference ?? .chinese },
            maxDepth: AgentConfig.maxDepth,
            maxThinkingTextLength: AgentConfig.maxThinkingTextLength,
            maxToolResultLength: AgentConfig.maxToolResultLength,
            immediateStreamFlushChars: AgentConfig.immediateStreamFlushChars,
            immediateThinkingFlushChars: AgentConfig.immediateThinkingFlushChars,
            streamUIFlushInterval: AgentConfig.streamUIFlushInterval,
            thinkingUIFlushInterval: AgentConfig.thinkingUIFlushInterval,
            captureThinkingContent: self.captureThinkingContent
        )
    }()

    private lazy var messages: ConversationTurnMiddlewareMessageActions = { [weak self] in
        guard let self else {
            return .init(
                messages: { [] },
                appendMessage: { _ in },
                updateMessage: { _, _ in },
                saveMessage: { _, _ in },
                enqueueTurnProcessing: { _, _ in },
                executeToolAndContinue: { _, _, _ in },
                updateRuntimeState: { _ in }
            )
        }
        return .init(
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
                await self.executeToolAndContinue(
                    toolCall,
                    conversationId: cid,
                    languagePreference: languagePreference
                )
            },
            updateRuntimeState: { [weak self] cid in self?.updateRuntimeState(for: cid) }
        )
    }()

    private lazy var ui: ConversationTurnMiddlewareUIActions = conversationTurnPipelineUIActions()

    private var pipeline: ConversationTurnPipeline?
    private var pluginsDidLoadObserver: NSObjectProtocol?

    init(
        llmService: LLMService,
        toolExecutionService: ToolExecutionService,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        chatHistoryService: ChatHistoryService,
        toolService: ToolService,
        messageViewModel: MessagePendingVM,
        ConversationVM: ConversationVM,
        projectVM: ProjectVM,
        processingStateViewModel: ProcessingStateVM,
        permissionRequestViewModel: PermissionRequestVM,
        thinkingStateViewModel: ThinkingStateVM,
        depthWarningViewModel: DepthWarningVM,
        captureThinkingContent: Bool = true
    ) {
        var continuation: AsyncStream<ConversationTurnEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation

        self.llmService = llmService
        self.toolExecutionService = toolExecutionService
        self.runtimeStore = runtimeStore
        self.sessionConfig = sessionConfig
        self.chatHistoryService = chatHistoryService
        self.toolService = toolService

        self.messageViewModel = messageViewModel
        self.ConversationVM = ConversationVM
        self.projectVM = projectVM

        self.processingStateViewModel = processingStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.thinkingStateViewModel = thinkingStateViewModel
        self.depthWarningViewModel = depthWarningViewModel

        self.captureThinkingContent = captureThinkingContent
    }

    // MARK: - 轮次事件消费（pipeline runner）

    func run() async {
        if pluginsDidLoadObserver == nil {
            pluginsDidLoadObserver = NotificationCenter.default.addObserver(
                forName: .pluginsDidLoad,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildPipeline()
                }
            }
        }

        rebuildPipeline()
        defer {
            if let pluginsDidLoadObserver {
                NotificationCenter.default.removeObserver(pluginsDidLoadObserver)
                self.pluginsDidLoadObserver = nil
            }
        }

        for await event in events {
            if Task.isCancelled { break }

            let start = CFAbsoluteTimeGetCurrent()
            let eventName = describe(event)
            let hangWatchdog = Task { [loggerTag = Self.t] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                AppLogger.core.error("\(loggerTag)⏳ 事件处理疑似卡住(>2s): \(eventName)")
            }

            let ctx = ConversationTurnMiddlewareContext(
                runtimeStore: runtimeStore,
                env: env,
                actions: messages,
                ui: ui
            )

            if let pipeline {
                await pipeline.run(event, ctx: ctx) { event, _ in
                    await self.handle(event)
                }
            } else {
                await handle(event)
            }

            hangWatchdog.cancel()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            if elapsed > 1 {
                AppLogger.core.error("\(Self.t)⏱️ 事件处理耗时异常: \(eventName) took \(String(format: "%.3f", elapsed))s")
            }
        }
    }

    private func rebuildPipeline() {
        let pluginMiddlewares = PluginVM.shared.getConversationTurnMiddlewares()
            .sorted { a, b in
                if a.order != b.order { return a.order < b.order }
                return a.id < b.id
            }

        let coreMiddlewares: [AnyConversationTurnMiddleware] = [
            AnyConversationTurnMiddleware(PingFilterMiddleware()),
            AnyConversationTurnMiddleware(PingHeartbeatMiddleware()),
            AnyConversationTurnMiddleware(StreamStartedInitializeMiddleware()),
            AnyConversationTurnMiddleware(StreamChunkAccumulateMiddleware()),
            AnyConversationTurnMiddleware(ThinkingDeltaCaptureMiddleware()),
            AnyConversationTurnMiddleware(ThinkingStartMiddleware()),
            AnyConversationTurnMiddleware(PermissionDecisionMiddleware()),
            AnyConversationTurnMiddleware(StreamEventIgnoreMiddleware()),
            AnyConversationTurnMiddleware(StreamTextDeltaApplyMiddleware()),
            AnyConversationTurnMiddleware(EmptyToolResponseContentMiddleware()),
            AnyConversationTurnMiddleware(ToolResultTruncateMiddleware()),
            AnyConversationTurnMiddleware(StreamFinishedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(MaxDepthReachedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(TurnCompletedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(PersistAndAppendMiddleware()),
            AnyConversationTurnMiddleware(ShouldContinueEnqueueMiddleware()),
            AnyConversationTurnMiddleware(TraceLoggingMiddleware())
        ]

        let all = (coreMiddlewares + pluginMiddlewares).sorted { a, b in
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }

        pipeline = ConversationTurnPipeline(
            middlewares: all.map { m in
                { event, ctx, next in
                    await m.handle(event: event, ctx: ctx, next: next)
                }
            }
        )
    }

    private func handle(_ event: ConversationTurnEvent) async {
        switch event {
        case let .error(error, conversationId):
            let msg = error.localizedDescription
            runtimeStore.errorMessageByConversation[conversationId] = msg
            runtimeStore.processingConversationIds.remove(conversationId)
            runtimeStore.turnContextsByConversation.removeValue(forKey: conversationId)

            if env.selectedConversationId() == conversationId {
                ui.onTurnFailedUI(conversationId, msg)
            }

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
            runtimeStore.streamingTextByConversation[conversationId] = nil
            runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
            runtimeStore.streamStartedAtByConversation[conversationId] = nil
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)
            messages.updateRuntimeState(conversationId)

        default:
            // 当前实现未使用 fallback：保留该分支用于后续扩展。
            break
        }
    }

    private func describe(_ event: ConversationTurnEvent) -> String {
        switch event {
        case .responseReceived: return "responseReceived"
        case .streamChunk: return "streamChunk"
        case .streamEvent: return "streamEvent"
        case .streamStarted: return "streamStarted"
        case .streamFinished: return "streamFinished"
        case .toolResultReceived: return "toolResultReceived"
        case .permissionRequested: return "permissionRequested"
        case .permissionDecision: return "permissionDecision"
        case .maxDepthReached: return "maxDepthReached"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }

    // MARK: - 轮次任务队列控制

    private var turnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    private var turnTaskGenerationByConversation: [UUID: Int] = [:]

    /// 撤销中断后不重建 UI VM：交由中间件/取消 handler 处理。
    func cancelTurnPipeline(for conversationId: UUID) {
        turnTaskPipelineByConversation[conversationId]?.cancel()
        turnTaskPipelineByConversation[conversationId] = nil
    }

    func resetUIAfterAgentCancel(for conversationId: UUID) {
        processingStateViewModel.setIsProcessing(false)
        thinkingStateViewModel.setIsThinking(false, for: conversationId)
        permissionRequestViewModel.setPendingPermissionRequest(nil)
    }

    // MARK: - 轮次事件产生逻辑（migrated from ConversationTurnVM）

    func enqueueTurnProcessing(conversationId: UUID, depth: Int) {
        let previousTask: Task<Void, Never>?
        if depth == 0 {
            if Self.verbose, turnTaskPipelineByConversation[conversationId] != nil {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId.uuidString.prefix(8))] 新消息到达，取消旧轮次链路")
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
            AppLogger.core.info("\(Self.t)🧵 [\(conversationId.uuidString.prefix(8))] 轮次入队 depth=\(depth), gen=\(generation)")
        }

        let task = Task { [weak self] in
            if let previousTask {
                await previousTask.value
            }
            guard let self else { return }

            if Self.verbose {
                AppLogger.core.info("\(self.t)🧵 [\(conversationId.uuidString.prefix(8))] 开始执行轮次 depth=\(depth), gen=\(generation)")
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

    // MARK: - 对话轮次处理

    private func processTurn(
        conversationId: UUID,
        depth: Int = 0,
        config: LLMConfig,
        messages: [ChatMessage],
        chatMode: ChatMode,
        tools: [AgentTool],
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        let depthGuardResult = MaxDepthReachedGuard().evaluate(depth: depth, maxDepth: AgentConfig.maxDepth)

        switch depthGuardResult {
        case let .reached(currentDepth, maxDepth):
            eventContinuation.yield(.maxDepthReached(currentDepth: currentDepth, maxDepth: maxDepth, conversationId: conversationId))
            return
        case .proceed:
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
            AppLogger.core.info("\(self.t)[\(conversationId.uuidString.prefix(8))] 开始处理轮次 (深度：\(depth), 模式：\(chatMode.displayName), 流式：true)")
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
            let responseMsg = try await processStreamingTurn(
                conversationId: conversationId,
                config: config,
                messages: effectiveMessages,
                availableTools: availableTools,
                languagePreference: languagePreference
            )

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
                    let explainMessage = ChatMessage.maxDepthToolLimitMessage(
                        languagePreference: languagePreference,
                        currentDepth: depth,
                        maxDepth: AgentConfig.maxDepth
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
                        repeatedToolSignatureThreshold: AgentConfig.repeatedToolSignatureThreshold,
                        repeatedToolWindowThreshold: AgentConfig.repeatedToolWindowThreshold,
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
                AppLogger.core.error("\(self.t)[\(conversationId.uuidString.prefix(8))] 对话处理失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - 流式响应处理

    nonisolated private static func shouldForwardStreamEvent(_ eventType: StreamEventType) -> Bool {
        switch eventType {
        case .ping, .contentBlockStart, .contentBlockStop, .messageDelta, .signatureDelta, .thinkingDelta:
            return true
        case .messageStart, .messageStop, .unknown, .contentBlockDelta, .inputJsonDelta, .textDelta:
            return false
        }
    }

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
                    let content: String = (eventType == .inputJsonDelta)
                        ? (chunk.partialJson ?? "")
                        : (chunk.content ?? "")
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

        let finalMessage = ChatMessage(
            id: messageId,
            role: .assistant,
            content: accumulatedContent,
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

    private func executeToolAndContinue(
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

    // MARK: - UI 动作闭包构建（migrated from ConversationTurnVM）

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
}
