import KitAgentTool
import Foundation
import KitLLM
import KitSuperLog
import os
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

// MARK: - ProviderMessage ↔ KitLLM 桥接

extension Message {
    var llmMessage: LLMMessage {
        LLMMessage(
            role: KitLLM.MessageRole(rawValue: role.rawValue) ?? .unknown,
            content: content,
            toolCalls: toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            images: (toolCalls ?? []).compactMap { $0.result }.flatMap { $0.imageAttachments }.map {
                MessageImage(data: Data(base64Encoded: $0.data) ?? Data(), mimeType: $0.mimeType)
            }
        )
    }
}

// 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
private typealias ToolCall = KitAgentTool.ToolCall

/// Agent 回合执行器（KernelCore 体系，完整复刻旧版 `AgentTurnRunner`）。
///
/// 回合循环：
/// 1. 把消息历史（含 tool 结果）发送给 LLM；
/// 2. 流式接收增量（text / thinking）写入 `MessageStreamingProviding`；
/// 3. 收到带工具调用的响应后逐个执行（按会话 automationLevel 评估授权，
///    高风险调用挂起等待用户批准/拒绝）；
/// 4. 工具结果以 `.tool` 消息落库，带回 LLM 继续下一轮；
/// 5. 直到 LLM 输出无工具调用的最终响应，回合完成。
///
/// 对齐旧版 `AgentTurnRunner` 语义：
/// - 会话级供应商/模型选择（`ConversationManaging` 为事实来源，全局选中兜底）；
/// - 流式优先（`LLMStreamingProviding`），未实现流式时回退 `complete(_:)`；
/// - `MessageStreamingProviding` 临时行 + 最终落库行分离，落库后清理临时行；
/// - 瞬时 status 消息（正在思考…/正在执行…）由 `MessageManaging` 仅存内存。
@MainActor
public final class DefaultAgentLoopProvider: AgentLoopProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-agent-loop", category: "AgentLoop")
    public nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true
    private let messages: any MessageManaging
    private let llmManager: any LLMManaging
    private let toolManager: any ToolManagerProviding
    private let streaming: any MessageStreamingProviding
    private let conversations: any ConversationManaging
    /// 生命周期钩子管理器：回合循环在各关键节点触发对应钩子。
    private var lifecycleHooks: (any LifecycleHooksProviding)?

    // MARK: - Turn State

    private var states: [UUID: AgentLoopState] = [:]
    private var tasks: [UUID: Task<AgentLoopOutcome, Never>] = [:]
    private var suspensions: [UUID: AgentLoopSuspension] = [:]
    /// 当前 assistant 工具批次中所有挂起的调用（一个批次可含多个 ask_user）。
    private var pendingSuspensions: [UUID: [String: AgentLoopSuspension]] = [:]
    private var turnIDs: [UUID: UUID] = [:]
    private var cancelledConversations: Set<UUID> = []
    private var awaitingConversations: Set<UUID> = []
    private var failedConversations: Set<UUID> = []
    private var agentLoopObservers: [UUID: (AgentLoopEvent) -> Void] = [:]
    private var eventTasks: [UUID: Task<Void, Never>] = [:]
    private var completionWaiters: [UUID: [CheckedContinuation<AgentLoopOutcome, Never>]] = [:]
    private var activeToolCalls: [UUID: (assistantID: UUID, calls: [MessageToolCall])] = [:]
    private var messageObserver: (any MessageInsertedObserverHandle)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    @Published public private(set) var revision: Int = 0

    public init(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging
    ) {
        self.messages = messages
        self.llmManager = llmManager
        self.toolManager = toolManager
        self.streaming = streaming
        self.conversations = conversations
        messageObserver = messages.addMessageInsertedObserver { [weak self] message, conversationID in
            guard message.role == .user else { return }
            Task { @MainActor in
                guard let self, !self.isRunning(for: conversationID) else { return }
                _ = try? await self.runTurn(in: conversationID)
            }
        }
        toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in
            Task { @MainActor in
                self?.handleToolManagerEvent(event)
            }
        }
    }

    @discardableResult
    public func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        agentLoopObservers[id] = callback
        return DefaultAgentLoopObserverHandle { [weak self] in
            self?.agentLoopObservers.removeValue(forKey: id)
        }
    }

    private func notify(_ event: AgentLoopEvent) {
        handleAgentLoopEvent(event)
        for callback in agentLoopObservers.values {
            callback(event)
        }
    }

    // MARK: - Injection

    public func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {
        lifecycleHooks = hooks
    }

    // MARK: - AgentLoopProviding

    public func state(for conversationID: UUID) -> AgentLoopState {
        states[conversationID] ?? .idle
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        tasks[conversationID] != nil || eventTasks[conversationID] != nil || states[conversationID] == .running
    }

    public func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        suspensions[conversationID]
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        turnIDs[conversationID]
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancel turn conversation=\(conversationID.uuidString.prefix(8))")
        }
        let turnID = turnIDs[conversationID]
        cancelledConversations.insert(conversationID)
        suspensions.removeValue(forKey: conversationID)
        pendingSuspensions.removeValue(forKey: conversationID)
        awaitingConversations.remove(conversationID)
        states[conversationID] = .cancelled
        tasks[conversationID]?.cancel()
        tasks.removeValue(forKey: conversationID)
        eventTasks[conversationID]?.cancel()
        eventTasks.removeValue(forKey: conversationID)
        let waiters = completionWaiters.removeValue(forKey: conversationID) ?? []
        waiters.forEach { $0.resume(returning: .cancelled) }
        revision += 1
        notify(.cancelled(conversationID: conversationID, turnID: turnID))
    }

    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)start turn conversation=\(conversationID.uuidString.prefix(8))")
        }
        guard !isRunning(for: conversationID) else {
            return .failed("turn already running")
        }

        cancelledConversations.remove(conversationID)
        failedConversations.remove(conversationID)

        let turnID = UUID()
        turnIDs[conversationID] = turnID
        states[conversationID] = .running
        revision += 1
        if let lifecycleHooks {
            await lifecycleHooks.notifyTurnStarted(TurnLifecycleContext(
                conversationID: conversationID, turnID: turnID
            ))
        }
        notify(.started(conversationID: conversationID, turnID: turnID))

        launchEventStep(conversationID: conversationID, turnID: turnID)
        return await waitForCompletion(conversationID: conversationID)
    }

    /// 恢复被挂起的回合：把用户回答写入工具结果，继续执行同一批次中剩余调用；
    /// 批次全部终态后开启新一轮 LLM 请求。
    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)resume turn conversation=\(conversationID.uuidString.prefix(8)), suspension=\(request.suspensionID)")
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

        let result = convertResult(await toolManager.resolveUserResponse(
            request.answer,
            for: ToolCall(id: toolCall.id, name: toolCall.name, arguments: toolCall.arguments),
            conversationID: conversationID,
            turnID: turnIDs[conversationID]
        ))

        // 更新 assistant 消息内的展示快照。
        messages.updateToolCallResult(result, toolCallID: toolCallID, assistantMessageID: assistantMessage.id, in: conversationID)
        // 把用户回答合并进已落库的 .tool 消息（LLM 下一轮可见）。
        if let pendingToolMessage = messages.messages(for: conversationID)
            .last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
            messages.updateMessage(
                id: pendingToolMessage.id,
                in: conversationID,
                content: result.content
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
        states[conversationID] = .running
        activeToolCalls.removeValue(forKey: conversationID)
        let completedIDs = Set(messages.messages(for: conversationID).compactMap {
            $0.role == .tool ? $0.toolCallID : nil
        })
        let remaining = (assistantMessage.toolCalls ?? []).filter { !completedIDs.contains($0.id) }
        if remaining.isEmpty {
            launchEventStep(conversationID: conversationID, turnID: turnIDs[conversationID] ?? UUID())
        } else {
            let turnID = turnIDs[conversationID] ?? UUID()
            activeToolCalls[conversationID] = (assistantMessage.id, remaining)
            let policy = toolExecutionPolicy(for: conversationID)
            let calls = remaining.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = await self.toolManager.executeBatch(calls, policy: policy, conversationID: conversationID, turnID: turnID)
            }
        }
        return await waitForCompletion(conversationID: conversationID)
    }

    // MARK: - Turn Loop

    private func launchEventStep(conversationID: UUID, turnID: UUID) {
        guard eventTasks[conversationID] == nil else { return }
        if Self.verbose {
            Self.logger.debug("\(Self.t)advance one step conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
        }
        eventTasks[conversationID] = Task { @MainActor [weak self] in
            await self?.advanceEventTurn(conversationID: conversationID, turnID: turnID)
        }
    }

    private func waitForCompletion(conversationID: UUID) async -> AgentLoopOutcome {
        await withCheckedContinuation { continuation in
            completionWaiters[conversationID, default: []].append(continuation)
        }
    }

    private func finishEventTurn(conversationID: UUID, turnID: UUID, outcome: AgentLoopOutcome) {
        if Self.verbose {
            Self.logger.info("\(Self.t)finish turn conversation=\(conversationID.uuidString.prefix(8)), outcome=\(String(describing: outcome))")
        }
        eventTasks[conversationID] = nil
        if case .suspended = outcome {
            // 挂起回合需要在 resume 时沿用原 turnID。
        } else {
            turnIDs[conversationID] = nil
        }
        revision += 1
        switch outcome {
        case .completed: notify(.completed(conversationID: conversationID, turnID: turnID))
        case .failed(let reason): notify(.failed(conversationID: conversationID, turnID: turnID, reason: reason))
        case .cancelled: notify(.cancelled(conversationID: conversationID, turnID: turnID))
        case .suspended:
            if let suspension = suspensions[conversationID] {
                notify(.suspended(conversationID: conversationID, turnID: turnID, suspension: suspension))
            }
        }
        let waiters = completionWaiters.removeValue(forKey: conversationID) ?? []
        waiters.forEach { $0.resume(returning: outcome) }
    }

    private func advanceEventTurn(conversationID: UUID, turnID: UUID) async {
        defer { eventTasks[conversationID] = nil }
        if cancelledConversations.contains(conversationID) {
            finishEventTurn(conversationID: conversationID, turnID: turnID, outcome: .cancelled)
            return
        }
        do {
            let response = try await requestOneLLM(conversationID: conversationID, turnID: turnID)
            let toolCalls = response.toolCalls
            guard !toolCalls.isEmpty else {
                states[conversationID] = .completed
                finishEventTurn(conversationID: conversationID, turnID: turnID, outcome: .completed)
                return
            }
            activeToolCalls[conversationID] = (response.assistantID, toolCalls)
            if Self.verbose {
                Self.logger.info("\(Self.t)LLM requested tools conversation=\(conversationID.uuidString.prefix(8)), count=\(toolCalls.count)")
            }
            notify(.toolCallsReceived(
                conversationID: conversationID,
                turnID: turnID,
                assistantMessageID: response.assistantID,
                toolCalls: toolCalls
            ))
        } catch {
            states[conversationID] = .failed
            finishEventTurn(conversationID: conversationID, turnID: turnID, outcome: .failed(String(describing: error)))
        }
    }

    private struct OneLLMResponse {
        let response: LLMResponse
        let assistantID: UUID
        var toolCalls: [MessageToolCall] { response.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) } ?? [] }
    }

    private func requestOneLLM(conversationID: UUID, turnID: UUID) async throws -> OneLLMResponse {
        if Self.verbose {
            Self.logger.debug("\(Self.t)request LLM conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8))")
        }
        let history = messages.messages(for: conversationID)
        let level = conversations.automationLevel(for: conversationID)
        let language = languagePreference(for: conversationID)
        let schemas = (level.allowsTools ? toolManager.allTools() : []).compactMap { tool in
            LLMFunctionSchema(name: tool.name, description: tool.description(for: language), parameters: tool.inputSchema(for: language))
        }
        var preparedHistory = history
        if let lifecycleHooks {
            let result = await lifecycleHooks.runWillSendToLLM(WillSendToLLMContext(messages: history.map(\.llmMessage), conversationID: conversationID))
            preparedHistory = result.messages.map { message in
                Message(conversationID: conversationID, role: .init(rawValue: message.role.rawValue) ?? .system, content: message.content, toolCallID: message.toolCallID, reasoningContent: message.reasoningContent)
            }
        }
        let request = LLMRequest(conversationID: conversationID, messages: preparedHistory.map(\.llmMessage), model: conversations.modelName(for: conversationID), tools: schemas.isEmpty ? nil : schemas, reasoningEffort: conversations.reasoningEffortOptional(for: conversationID).flatMap { $0.rawValue })
        streaming.start(conversationID: conversationID)
        let response: LLMResponse
        do {
            if let streamingManager = llmManager as? any LLMStreamingProviding {
                let bridge = StreamingBridge(streaming: streaming)
                response = try await streamingManager.streamComplete(request) { [weak bridge] chunk in
                    guard let bridge else { return }
                    if let reasoning = chunk.reasoningContent, !reasoning.isEmpty {
                        await bridge.appendThinking(reasoning, conversationID: conversationID)
                    } else {
                        await bridge.appendContent(chunk.content ?? "", conversationID: conversationID)
                    }
                }
            } else {
                response = try await llmManager.complete(request)
            }
        } catch {
            streaming.end(conversationID: conversationID)
            await appendError(in: conversationID, error: error, turnID: turnID)
            throw error
        }
        if Self.verbose {
            Self.logger.debug("\(Self.t)LLM response received conversation=\(conversationID.uuidString.prefix(8)), hasTools=\(!(response.toolCalls ?? []).isEmpty)")
        }
        var assistant = Message(conversationID: conversationID, role: .assistant, content: response.content, turnID: turnID, providerID: nil, modelName: response.model, reasoningContent: response.reasoningContent, toolCalls: response.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }, inputTokenCount: response.inputTokenCount, outputTokenCount: response.outputTokenCount)
        assistant.providerID = resolvedProviderID(for: conversationID)
        if let calls = assistant.toolCalls {
            assistant.toolCalls = calls.map { call in
                var enriched = call
                enriched.displayDescription = toolManager.displayDescription(for: ToolCall(id: call.id, name: call.name, arguments: call.arguments))
                return enriched
            }
        }
        messages.insertMessage(assistant, to: conversationID)
        streaming.end(conversationID: conversationID)
        if let lifecycleHooks {
            await lifecycleHooks.notifyDidReceiveLLMResponse(DidReceiveLLMResponseContext(response: response, requestMessages: preparedHistory.map(\.llmMessage), conversationID: conversationID))
        }
        return OneLLMResponse(response: response, assistantID: assistant.id)
    }

    private func handleToolManagerEvent(_ event: ToolManagerEvent) {
        guard case .batchCompleted(let conversationID, let eventTurnID, let calls, let results) = event,
              let turnID = turnIDs[conversationID], eventTurnID == nil || eventTurnID == turnID,
              let active = activeToolCalls[conversationID] else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)tool batch completed conversation=\(conversationID.uuidString.prefix(8)), count=\(results.count)")
        }
        var firstSuspension: AgentLoopSuspension?
        let assistantMessage = messages.messages(for: conversationID).reversed().first(where: { $0.id == active.assistantID })
        for (call, batchResult) in zip(calls, results) {
            let result: MessageToolResult
            switch batchResult {
            case .executed(let value): result = convertResult(value)
            case .blocked(let reason): result = MessageToolResult(content: reason, isError: true)
            case .needsUserResponse(let payload):
                firstSuspension = AgentLoopSuspension(
                    suspensionID: "userInput:\(call.id)",
                    conversationID: conversationID,
                    toolCallID: call.id,
                    kind: "userInput",
                    payload: payload
                )
                result = MessageToolResult(content: firstSuspension?.payload ?? "", awaitingUserResponse: true)
            }
            if let assistantMessage {
                messages.updateToolCallResult(result, toolCallID: call.id, assistantMessageID: assistantMessage.id, in: conversationID)
            }
            insertToolResultMessage(result, toolCallID: call.id, conversationID: conversationID, turnID: turnID)
            if result.awaitingUserResponse && firstSuspension == nil {
                firstSuspension = AgentLoopSuspension(suspensionID: "userInput:\(call.id)", conversationID: conversationID, toolCallID: call.id, kind: "userInput", payload: result.content)
            }
            if firstSuspension != nil { break }
        }
        activeToolCalls.removeValue(forKey: conversationID)
        if let suspension = firstSuspension {
            suspensions[conversationID] = suspension
            pendingSuspensions[conversationID] = [suspension.toolCallID ?? "": suspension]
            awaitingConversations.insert(conversationID)
            states[conversationID] = .suspended
            finishEventTurn(conversationID: conversationID, turnID: turnID, outcome: .suspended(suspension.suspensionID))
        } else {
            states[conversationID] = .running
            launchEventStep(conversationID: conversationID, turnID: turnID)
        }
    }

    private func handleAgentLoopEvent(_ event: AgentLoopEvent) {
        let conversationID: UUID
        let turnID: UUID
        let toolCalls: [MessageToolCall]
        switch event {
        case .toolCallsReceived(let id, let eventTurnID, _, let calls):
            conversationID = id
            turnID = eventTurnID
            toolCalls = calls
        case .llmResponseReceived(let id, let eventTurnID, let calls):
            // 兼容外部旧 AgentLoop 实现。
            conversationID = id
            turnID = eventTurnID
            toolCalls = calls
        default:
            return
        }
        guard !toolCalls.isEmpty else { return }
        let calls = toolCalls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.toolManager.executeBatch(
                calls,
                policy: self.toolExecutionPolicy(for: conversationID),
                conversationID: conversationID,
                turnID: turnID
            )
        }
    }

    private func toolExecutionPolicy(for conversationID: UUID) -> ToolExecutionPolicy {
        switch conversations.automationLevel(for: conversationID) {
        case .chat: return .blockAll
        case .autonomous: return .autoExecute
        case .build: return .requireApprovalForHighRisk
        }
    }

    // Kept only as a compatibility reference for old recovery data; active
    // turns use the event-driven step path above and never call this method.
    @available(*, unavailable, message: "Use the event-driven step path")
    private func legacyExecuteTurnStep(conversationID: UUID, turnID: UUID) async -> AgentLoopOutcome {
        guard !cancelledConversations.contains(conversationID) else {
            states[conversationID] = .cancelled
            return .cancelled
        }
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
                    return .suspended("awaiting user response")
                }
                return .failed("legacy turn path disabled")
            }

            // 会话设置是事实来源：automationLevel 决定是否附带工具。
            let automationLevel = conversations.automationLevel(for: conversationID)
            let tools = automationLevel.allowsTools ? toolManager.allTools() : []
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

            // LLM 请求前的消息准备钩子（对齐旧版 willSendToLLM）：
            // 详细度 / 语言 / 自动化级别等插件按注册顺序串行修改消息历史，
            // 注入 system 指令（不落库，仅本次请求生效）。
            var preparedHistory = history
            // 生命周期钩子 willSendToLLM：插件可在 LLM 请求前修改消息历史。
            if let lifecycleHooks {
                let ctx = WillSendToLLMContext(
                    messages: preparedHistory.map(\.llmMessage),
                    conversationID: conversationID
                )
                let result = await lifecycleHooks.runWillSendToLLM(ctx)
                preparedHistory = result.messages.map { msg in
                    Message(
                        conversationID: conversationID,
                        role: .init(rawValue: msg.role.rawValue) ?? .system,
                        content: msg.content,
                        toolCallID: msg.toolCallID,
                        reasoningContent: msg.reasoningContent
                    )
                }
            }

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
                if let streamingManager = llmManager as? any LLMStreamingProviding {
                    // streaming 是 MainActor 隔离的存在类型，不能直接捕获进
                    // @Sendable 流式回调；用 @unchecked Sendable 桥接包装，
                    // 在回调内经 await 跳回 MainActor 写入。
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
                } else {
                    response = try await llmManager.complete(request)
                }
            } catch {
                streaming.end(conversationID: conversationID)
                await appendError(in: conversationID, error: error, turnID: turnID)
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
                toolCalls: response.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
                inputTokenCount: response.inputTokenCount,
                outputTokenCount: response.outputTokenCount
            )
            assistant.providerID = resolvedProviderID(for: conversationID)
            if let toolCalls = assistant.toolCalls {
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
            streaming.end(conversationID: conversationID)
            notify(.toolCallsReceived(
                conversationID: conversationID,
                turnID: turnID,
                assistantMessageID: assistant.id,
                toolCalls: assistant.toolCalls?.map { MessageToolCall(
                    id: $0.id,
                    name: $0.name,
                    arguments: $0.arguments
                ) } ?? []
            ))
            // 生命周期钩子 didReceiveLLMResponse：插件可在 LLM 响应到达后执行逻辑。
            if let lifecycleHooks {
                await lifecycleHooks.notifyDidReceiveLLMResponse(DidReceiveLLMResponseContext(
                    response: response,
                    requestMessages: preparedHistory.map(\.llmMessage),
                    conversationID: conversationID
                ))
            }

            // 无工具调用 → 回合完成。
            guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
                states[conversationID] = .completed
                return .completed
            }

            // 执行整批工具调用；挂起的调用记录后独立作答。
            var batchSuspensions: [String: AgentLoopSuspension] = [:]
            for toolCall in toolCalls where toolCall.result == nil {
                try? Task.checkCancellation()
                if cancelledConversations.contains(conversationID) {
                    return .cancelled
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
                        awaitingUserResponse: true,
                        interactionState: result.interactionState
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
                return .suspended("awaiting user response")
            }

            // 工具结果已入历史，进入下一次异步单步推进。
            return .failed("legacy turn path disabled")
    }

    // MARK: - Tool Execution

    /// 工具执行委托给 ToolManager；AgentLoop 只处理通用结果和挂起。
    private func executeToolCall(
        _ toolCall: MessageToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> MessageToolResult {
        let tool = ToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        let policy: ToolExecutionPolicy
        switch conversations.automationLevel(for: conversationID) {
        case .chat: policy = .blockAll
        case .autonomous: policy = .autoExecute
        case .build: policy = .requireApprovalForHighRisk
        }
        guard let batchResult = await toolManager.executeBatch(
            [tool], policy: policy, conversationID: conversationID, turnID: turnID
        ).first else { return MessageToolResult(content: "Tool execution returned no result.", isError: true) }
        switch batchResult {
        case .executed(let result): return convertResult(result)
        case .blocked(let reason): return MessageToolResult(content: reason, isError: true)
        case .needsUserResponse(let payload):
            let suspension = AgentLoopSuspension(
                suspensionID: "userInput:\(toolCall.id)", conversationID: conversationID,
                toolCallID: toolCall.id, kind: "userInput", payload: payload
            )
            suspensions[conversationID] = suspension
            return MessageToolResult(content: payload, awaitingUserResponse: true)
        }
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
            awaitingUserResponse: result.awaitingUserResponse,
            interactionState: result.interactionState.map {
                switch $0 {
                case .waiting: return .waiting
                case .answered(let answer): return .answered(answer)
                }
            }
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
        guard let toolCalls = assistantMessage.toolCalls else {
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
                    awaitingUserResponse: true,
                    interactionState: result.interactionState
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

    private func appendError(in conversationID: UUID, content: String, turnID: UUID? = nil) async {
        let errorMessage = Message(
            conversationID: conversationID,
            role: .error,
            content: content,
            turnID: turnID
        )
        messages.insertMessage(errorMessage, to: conversationID)
    }

    /// 从 `Error` 构造错误消息，透传渲染元数据（`renderKind` / `rawErrorDetail`），
    /// 让 Key 缺失等错误命中专用渲染器（如 API Key 输入卡）；同时带上会话绑定的
    /// 供应商 id，供渲染器解析供应商（否则 provider==nil 会把输入框 disabled）。
    private func appendError(in conversationID: UUID, error: Error, turnID: UUID? = nil) async {
        let renderInfo = error as? any LLMErrorRenderInfo
        let errorMessage = Message(
            conversationID: conversationID,
            role: .error,
            content: error.localizedDescription,
            turnID: turnID,
            providerID: resolvedProviderID(for: conversationID),
            rawErrorDetail: renderInfo?.rawErrorDetail,
            renderKind: renderInfo?.renderKind
        )
        messages.insertMessage(errorMessage, to: conversationID)
    }

    private func languagePreference(for conversationID: UUID) -> LanguagePreference {
        let language = conversations.language(for: conversationID)
        switch language {
        case .chinese: return .chinese
        case .english: return .english
        }
    }

    private func resolvedProviderID(for conversationID: UUID) -> String? {
        conversations.providerID(for: conversationID)
    }

}

public extension Array where Element == MessageToolCall {
    /// 批次中所有调用是否都已终态（有结果或已挂起等待）。
    var isTerminalToolBatch: Bool {
        !contains { $0.result == nil }
    }
}

public enum AgentLoopError: Error, LocalizedError {
    case invalidResumeRequest
    case unsupportedStreaming

    public var errorDescription: String? {
        switch self {
        case .invalidResumeRequest: return "The resume request does not match a suspended tool call."
        case .unsupportedStreaming: return "The selected LLM provider does not support streaming."
        }
    }
}

/// 把 MainActor 隔离的流式 store 桥接为 `@Sendable` 可捕获值。
///
/// `MessageStreamingProviding` 是 MainActor 隔离的存在类型，不能直接捕获进
/// `LLMStreamingProviding.streamComplete` 的 `@Sendable` 回调；本包装类标记
/// `@unchecked Sendable`，回调内经 `await` 跳回 MainActor 写入，保证对
/// `@Published` 的写安全。
private final class StreamingBridge: @unchecked Sendable {
    private let streaming: any MessageStreamingProviding

    init(streaming: any MessageStreamingProviding) {
        self.streaming = streaming
    }

    @MainActor
    func appendContent(_ content: String, conversationID: UUID) {
        streaming.appendContent(content, conversationID: conversationID)
    }

    @MainActor
    func appendThinking(_ content: String, conversationID: UUID) {
        streaming.appendThinking(content, conversationID: conversationID)
    }
}
