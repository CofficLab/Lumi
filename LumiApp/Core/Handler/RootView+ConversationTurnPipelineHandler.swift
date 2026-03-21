import Foundation
import MagicKit

/// 轮次执行逻辑：由 RootView 驱动，状态存放在 RootViewContainer。
@MainActor
extension RootView {
    private var eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation { container.conversationTurnEventContinuation }

    private var llmService: LLMService { container.llmService }
    private var toolExecutionService: ToolExecutionService { container.toolExecutionService }
    private var runtimeStore: ConversationRuntimeStore { container.conversationRuntimeStore }
    private var sessionConfig: AgentSessionConfig { container.agentSessionConfig }
    private var chatHistoryService: ChatHistoryService { container.chatHistoryService }
    private var toolService: ToolService { container.toolService }
    private var messageViewModel: MessagePendingVM { container.messageViewModel }
    private var ConversationVM: ConversationVM { container.ConversationVM }
    private var projectVM: ProjectVM { container.ProjectVM }
    private var processingStateViewModel: ProcessingStateVM { container.processingStateViewModel }
    private var permissionRequestViewModel: PermissionRequestVM { container.permissionRequestViewModel }
    private var thinkingStateViewModel: ThinkingStateVM { container.thinkingStateViewModel }
    private var depthWarningViewModel: DepthWarningVM { container.depthWarningViewModel }
    private var captureThinkingContent: Bool { container.captureThinkingContent }

    // MARK: - 轮次事件消费（pipeline runner）

    private func makeEnvironment() -> ConversationTurnMiddlewareEnvironment {
        .init(
            selectedConversationId: { [conversationVM = ConversationVM] in conversationVM.selectedConversationId },
            languagePreference: { [projectVM] in projectVM.languagePreference },
            maxDepth: AgentConfig.maxDepth,
            maxThinkingTextLength: AgentConfig.maxThinkingTextLength,
            maxToolResultLength: AgentConfig.maxToolResultLength,
            immediateStreamFlushChars: AgentConfig.immediateStreamFlushChars,
            immediateThinkingFlushChars: AgentConfig.immediateThinkingFlushChars,
            streamUIFlushInterval: AgentConfig.streamUIFlushInterval,
            thinkingUIFlushInterval: AgentConfig.thinkingUIFlushInterval,
            captureThinkingContent: captureThinkingContent
        )
    }

    private func makeMessageActions() -> ConversationTurnMiddlewareMessageActions {
        .init(
            messages: { [messageViewModel] in messageViewModel.messages },
            appendMessage: { [messageViewModel] m in messageViewModel.appendMessage(m) },
            updateMessage: { [messageViewModel] m, idx in messageViewModel.updateMessage(m, at: idx) },
            saveMessage: { [conversationVM = ConversationVM] m, cid in
                await conversationVM.saveMessage(m, to: cid)
            },
            enqueueTurnProcessing: { cid, depth in
                self.enqueueTurnProcessing(conversationId: cid, depth: depth)
            },
            executeToolAndContinue: { toolCall, cid, languagePreference in
                await self.executeToolAndContinue(
                    toolCall,
                    conversationId: cid,
                    languagePreference: languagePreference
                )
            },
            updateRuntimeState: { cid in self.updateRuntimeState(for: cid) }
        )
    }

    func runConversationTurnPipeline() async {
        if container.conversationTurnPluginsDidLoadObserver == nil {
            container.conversationTurnPluginsDidLoadObserver = NotificationCenter.default.addObserver(
                forName: .pluginsDidLoad,
                object: nil,
                queue: nil
            ) { _ in
                Task { @MainActor in
                    self.rebuildPipeline()
                }
            }
        }

        rebuildPipeline()
        defer {
            if let pluginsDidLoadObserver = container.conversationTurnPluginsDidLoadObserver {
                NotificationCenter.default.removeObserver(pluginsDidLoadObserver)
                container.conversationTurnPluginsDidLoadObserver = nil
            }
        }

        for await event in container.conversationTurnEvents {
            if Task.isCancelled { break }

            let start = CFAbsoluteTimeGetCurrent()
            let eventName = event.debugName
            let env = self.makeEnvironment()
            let messages = self.makeMessageActions()
            let projection = self.conversationTurnPipelineProjectionActions()

            let ctx = ConversationTurnMiddlewareContext(
                runtimeStore: runtimeStore,
                env: env,
                actions: messages,
                projection: projection
            )

            if let pipeline = container.conversationTurnPipeline {
                await pipeline.run(event, ctx: ctx) { event, _ in
                    await self.handle(event, ctx: ctx)
                }
            } else {
                await self.handle(event, ctx: ctx)
            }

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

        container.conversationTurnPipeline = ConversationTurnPipeline(
            middlewares: all.map { m in
                { event, ctx, next in
                    await m.handle(event: event, ctx: ctx, next: next)
                }
            }
        )
    }

    private func handle(_ event: ConversationTurnEvent, ctx: ConversationTurnMiddlewareContext) async {
        switch event {
        case let .error(error, conversationId):
            let msg = error.localizedDescription
            runtimeStore.errorMessageByConversation[conversationId] = msg
            runtimeStore.clearRuntimeForTurnTermination(for: conversationId)

            if ctx.env.selectedConversationId() == conversationId {
                ctx.projection.onTurnFailedUI(conversationId, msg)
            }

            ctx.actions.updateRuntimeState(conversationId)

        default:
            // 当前实现未使用 fallback：保留该分支用于后续扩展。
            break
        }
    }

    // MARK: - 轮次任务队列控制

    /// 撤销中断后不重建 UI VM：交由中间件/取消 handler 处理。
    func cancelTurnPipeline(for conversationId: UUID) {
        container.conversationTurnTaskPipelineByConversation[conversationId]?.cancel()
        container.conversationTurnTaskPipelineByConversation[conversationId] = nil
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
            if Self.verbose, container.conversationTurnTaskPipelineByConversation[conversationId] != nil {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId.uuidString.prefix(8))] 新消息到达，取消旧轮次链路")
            }
            container.conversationTurnTaskPipelineByConversation[conversationId]?.cancel()
            container.conversationTurnTaskPipelineByConversation[conversationId] = nil
            previousTask = nil
        } else {
            previousTask = container.conversationTurnTaskPipelineByConversation[conversationId]
        }

        let generation = (container.conversationTurnTaskGenerationByConversation[conversationId] ?? 0) + 1
        container.conversationTurnTaskGenerationByConversation[conversationId] = generation
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🧵 [\(conversationId.uuidString.prefix(8))] 轮次入队 depth=\(depth), gen=\(generation)")
        }

        let task = Task {
            if let previousTask {
                await previousTask.value
            }
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🧵 [\(conversationId.uuidString.prefix(8))] 开始执行轮次 depth=\(depth), gen=\(generation)")
            }

            await self.runTurnJob(conversationId: conversationId, depth: depth)

            await MainActor.run {
                if container.conversationTurnTaskGenerationByConversation[conversationId] == generation {
                    container.conversationTurnTaskPipelineByConversation[conversationId] = nil
                }
            }
        }

        container.conversationTurnTaskPipelineByConversation[conversationId] = task
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

        var context = runtimeStore.beginOrAdvanceTurnContext(
            conversationId: conversationId,
            depth: depth,
            providerId: config.providerId
        )

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
                runtimeStore.resetToolLoopTracking(for: conversationId)
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
                if eventType.shouldForwardToTurnPipelineEvent {
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

    private func conversationTurnPipelineProjectionActions() -> ConversationTurnMiddlewareProjectionActions {
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
            onStreamStartedUI: { _, conversationId in
                processing.markStreamStarted()
                if ConversationVM.selectedConversationId == conversationId {
                    runtimeStore.bumpStreamingPresentation()
                }
            },
            onStreamFirstTokenUI: { _, ttftMs in
                if let ttftMs {
                    processing.markFirstToken(ttftMs: ttftMs)
                } else {
                    processing.markGenerating()
                }
            },
            onStreamFinishedUI: { conversationId in
                thinking.setThinkingText(
                    runtimeStore.thinkingTextByConversation[conversationId] ?? "",
                    for: conversationId
                )
                thinking.setIsThinking(false, for: conversationId)
                processing.finish()
                runtimeStore.streamingTextByConversation[conversationId] = nil
                if ConversationVM.selectedConversationId == conversationId {
                    runtimeStore.bumpStreamingPresentation()
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
