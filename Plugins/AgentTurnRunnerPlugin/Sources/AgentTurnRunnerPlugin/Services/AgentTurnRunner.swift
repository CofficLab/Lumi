import Foundation
import LumiKernel
import os
import SuperLogKit

/// Implementation of `AgentTurnManaging` that executes a full agent turn.
///
/// The agent turn loop:
/// 1. Send messages to LLM
/// 2. Receive response (possibly with tool calls)
/// 3. For each tool call:
///    a. Check risk level → request user permission if needed
///    b. Execute the tool
///    c. Append tool result message to conversation
/// 4. Repeat until LLM produces final response (no tool calls)
/// 5. Append final assistant message and return outcome
///
/// Sends notifications:
/// - `.lumiMessageSaved` after each message is persisted
/// - `.lumiTurnStarted` when a turn starts running
/// - `.lumiTurnCompleted` when turn ends normally (completed)
/// - `.lumiTurnFinished` when turn ends (any reason)
@MainActor
public final class AgentTurnRunner: AgentTurnManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    public nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - Properties

    weak var kernel: LumiKernel?
    var activeTurnTasks: [UUID: Task<Void, Never>] = [:]
    var cancelledConversations: Set<UUID> = []
    /// 因工具请求用户交互而暂停的对话。
    var awaitingConversations: Set<UUID> = []
    /// All suspended calls in the current assistant tool-call batch, keyed by
    /// their original tool-call ID. A batch may contain multiple ask_user
    /// calls, so one suspension per conversation is not sufficient.
    var pendingSuspensions: [UUID: [String: AgentTurnSuspension]] = [:]
    var suspensions: [UUID: AgentTurnSuspension] = [:]
    var turnStates: [UUID: AgentTurnState] = [:]
    var turnIDs: [UUID: UUID] = [:]
    var resumingTurnIDs: Set<UUID> = []
    var failedConversations: Set<UUID> = []
    var pendingChildWorks: [UUID: [String: AgentTurnChildWork]] = [:]
    var activeChildWorks: [UUID: Task<Void, Never>] = [:]
    var turnCreationExcludedToolNames: [UUID: Set<String>] = [:]
    var parentConversationIDs: [UUID: UUID] = [:]

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    // MARK: - AgentTurnManaging

    public func createTurn(_ request: AgentTurnCreationRequest) async throws -> AgentTurnHandle {
        let task = request.task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty, let kernel else {
            throw AgentTurnManagingError.invalidCreationRequest
        }
        guard let conversations = kernel.conversations else {
            throw LumiKernelError.serviceNotAvailable(service: "Conversation")
        }
        guard let messageManager = kernel.messageManager else {
            throw LumiKernelError.serviceNotAvailable(service: "Message")
        }

        let conversationID = try conversations.createConversation(
            title: request.title,
            projectPath: kernel.project?.currentProject?.path,
            providerID: request.providerID,
            modelName: request.modelID,
            parentConversationID: request.parentConversationID
        )
        parentConversationIDs[conversationID] = request.parentConversationID
        defer { parentConversationIDs.removeValue(forKey: conversationID) }
        turnCreationExcludedToolNames[conversationID] = request.excludedToolNames
        defer { turnCreationExcludedToolNames.removeValue(forKey: conversationID) }

        if let systemPrompt = request.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !systemPrompt.isEmpty {
            messageManager.insertMessage(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .system,
                    content: systemPrompt
                ),
                to: conversationID
            )
        }

        messageManager.insertMessage(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: task
            ),
            to: conversationID
        )

        _ = try await runTurn(in: conversationID)
        guard let turnID = currentTurnID(for: conversationID) else {
            throw AgentTurnManagingError.turnFailed
        }
        return AgentTurnHandle(conversationID: conversationID, turnID: turnID)
    }

    public func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)runTurn 开始 ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        // Guard against concurrent turns for the same conversation
        guard activeTurnTasks[conversationID] == nil else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)runTurn 跳过，conversation 已存在活跃 turn")
            }
            return .cancelled
        }

        // Clear cancellation flag for this conversation
        cancelledConversations.remove(conversationID)
        failedConversations.remove(conversationID)
        let turnID: UUID
        if resumingTurnIDs.remove(conversationID) != nil,
           let existingTurnID = turnIDs[conversationID] {
            turnID = existingTurnID
        } else {
            turnID = UUID()
            turnIDs[conversationID] = turnID
        }
        turnStates[conversationID] = .running

        let task = Task { [weak self] in
            guard let self else { return }
            await self.executeTurnLoop(conversationID: conversationID)
        }
        activeTurnTasks[conversationID] = task
        postTurnStartedNotification(
            conversationID: conversationID,
            turnID: turnID,
            parentConversationID: parentConversationIDs[conversationID]
        )

        // Wait for turn to complete
        await task.value
        activeTurnTasks.removeValue(forKey: conversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)runTurn 结束 ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        // Determine outcome based on cancellation state
        if cancelledConversations.contains(conversationID) {
            cancelledConversations.remove(conversationID)
            turnStates[conversationID] = .cancelled
            await postTurnFinishedNotification(conversationID: conversationID, reason: .cancelled)
            return .cancelled
        }

        if awaitingConversations.contains(conversationID) {
            awaitingConversations.remove(conversationID)
            if let suspension = suspensions[conversationID] {
                turnStates[conversationID] = .suspended(suspension)
            }
            await postTurnFinishedNotification(conversationID: conversationID, reason: .awaitingUserResponse)
            startChildWorkIfNeeded(for: conversationID)
            return .awaitingUserResponse
        }

        if failedConversations.remove(conversationID) != nil {
            turnStates[conversationID] = .failed
            await postTurnFinishedNotification(conversationID: conversationID, reason: .failed)
            return .failed(AgentTurnManagingError.turnFailed)
        }

        turnStates[conversationID] = .completed
        await postTurnCompletedNotification(conversationID: conversationID)
        return .completed
    }

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome {
        // The suspended tool posts its message-change notification before the
        // outer runTurn() has removed activeTurnTasks. A user can therefore
        // answer while that task is still unwinding. Wait for that lifecycle
        // to finish before starting the resumed turn; otherwise runTurn()
        // treats the resume as a concurrent turn and returns .cancelled.
        if let activeTask = activeTurnTasks[conversationID] {
            await activeTask.value
            activeTurnTasks.removeValue(forKey: conversationID)
        }

        let suspension = pendingSuspensions[conversationID]?.values.first(where: {
            $0.suspensionID == request.suspensionID
        }) ?? suspensions[conversationID] ?? persistedSuspension(
            for: conversationID,
            suspensionID: request.suspensionID
        )
        guard let suspension,
              suspension.suspensionID == request.suspensionID,
              let assistantMessage = kernel?.messageManager?.messages(for: conversationID)
              .reversed()
              .first(where: { message in
                  message.role == .assistant
                      && message.toolCalls?.contains(where: { $0.id == suspension.toolCallID }) == true
              }),
              let toolCallID = suspension.toolCallID
        else {
            throw AgentTurnManagingError.invalidResumeRequest
        }

        let result = LumiToolResult(
            content: suspension.payload,
            turnControl: .resumed(suspension, answer: request.answer)
        )
        kernel?.messageManager?.updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessage.id,
            in: conversationID
        )

        // Replace the pending tool message that was inserted into the LLM history.
        if let pendingToolMessage = kernel?.messageManager?.messages(for: conversationID)
            .last(where: { $0.role == .tool && $0.toolCallID == toolCallID }) {
            kernel?.messageManager?.updateMessage(
                id: pendingToolMessage.id,
                in: conversationID,
                content: request.answer
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

        let latestToolCalls = latestAssistantToolCalls(in: conversationID)
        guard latestToolCalls?.isTerminalToolBatch == true else {
            // Other interactive calls in this batch are still waiting. The
            // answer is persisted above, but no new LLM turn is started yet.
            turnStates[conversationID] = .suspended(suspension)
            return .awaitingUserResponse
        }

        turnStates[conversationID] = .running
        // This is intentionally a fresh turn. The answered tool result is now
        // part of the durable conversation history, so no special resume mode
        // is needed for the next LLM request.
        return try await runTurn(in: conversationID)
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancelTurn ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        // 先快照出所有仍把 `conversationID` 作为 parent 的 child turn。
        // 必须在修改任何 `activeTurnTasks` / `parentConversationIDs` 之前快照,
        // 否则递归取消会改变我们正在遍历的集合。
        let childIDs = activeTurnTasks.keys.filter {
            parentConversationIDs[$0] == conversationID
        }
        if Self.verbose && !childIDs.isEmpty {
            let preview = childIDs.map { $0.uuidString.prefix(8) }.joined(separator: ", ")
            Self.logger.info("\(Self.t)cancelTurn 级联 ➡️ parent=\(conversationID.uuidString.prefix(8))…, children=[\(preview)]")
        }
        for childID in childIDs {
            cancelTurn(in: childID)
        }

        cancelledConversations.insert(conversationID)
        suspensions.removeValue(forKey: conversationID)
        pendingChildWorks.removeValue(forKey: conversationID)
        pendingSuspensions.removeValue(forKey: conversationID)
        turnCreationExcludedToolNames.removeValue(forKey: conversationID)
        activeChildWorks[conversationID]?.cancel()
        activeChildWorks.removeValue(forKey: conversationID)
        turnStates[conversationID] = .cancelled
        activeTurnTasks[conversationID]?.cancel()
        activeTurnTasks.removeValue(forKey: conversationID)
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        activeTurnTasks[conversationID] != nil
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        turnIDs[conversationID]
    }

    public func state(for conversationID: UUID) -> AgentTurnState {
        if let state = turnStates[conversationID] {
            return state
        }
        if let suspension = persistedSuspension(for: conversationID) {
            return .suspended(suspension)
        }
        return .idle
    }

    // MARK: - Turn Loop

    // MARK: - Historical Records (AgentTurnManaging protocol)

    /// Aggregates `AgentTurnRecord` from existing data sources:
    /// - `AgentTurnRecordStore`: turnIDs + timestamps (from LLM request records)
    /// - `MessageManaging`: token statistics (from messages with matching turnID)
    /// - `ToolManaging`: tool call statistics (from tool call records)
    /// - Memory `turnStates`: live state overlay for active turns
    public func turnRecords(
        for conversationID: UUID,
        limit: Int,
        before turnID: UUID?
    ) async -> [AgentTurnRecord] {
        guard let store = AgentTurnRunnerRecordStoreBridge.shared.store else { return [] }

        // 1. Get all turn IDs from LLM request records
        let allTurnIDs = await store.fetchTurnIDs(for: conversationID)
        guard !allTurnIDs.isEmpty else { return [] }

        // 2. Apply pagination (before cursor)
        let orderedIDs: [UUID]
        if let turnID {
            // Find the cursor position and take IDs before it
            guard let cursorIndex = allTurnIDs.firstIndex(of: turnID) else { return [] }
            let startIndex = max(0, cursorIndex - limit)
            orderedIDs = Array(allTurnIDs[startIndex..<cursorIndex].reversed())
        } else {
            // Take the last `limit` IDs (newest first)
            orderedIDs = Array(allTurnIDs.suffix(limit).reversed())
        }

        // 3. Read the conversation once, then aggregate each turn from that
        // shared snapshot. Reading the full history once per turn creates an
        // avoidable N+1 query when a UI requests a page of records.
        let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
        var records: [AgentTurnRecord] = []
        for tid in orderedIDs {
            let record = await aggregateTurnRecord(
                turnID: tid,
                conversationID: conversationID,
                store: store,
                messages: messages
            )
            records.append(record)
        }

        return records
    }

    public func turnRecord(id turnID: UUID) async -> AgentTurnRecord? {
        guard let store = AgentTurnRunnerRecordStoreBridge.shared.store else { return nil }

        // Check if this is a currently active turn
        for (conversationID, currentTurnID) in turnIDs where currentTurnID == turnID {
            let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
            return await aggregateTurnRecord(
                turnID: turnID,
                conversationID: conversationID,
                store: store,
                messages: messages
            )
        }

        // For completed turns, caller should use turnRecords(for:) with known conversationID
        // since we don't have a global turn index
        return nil
    }

    public func deleteTurnRecords(for conversationID: UUID) async {
        // Turn data is derived from LLM request records + messages + tool calls.
        // Conversation deletion already cascades to those sources:
        // - ToolManaging.deleteToolCalls(for:) handles tool records
        // - ConversationStore deletion handles messages
        // - LLM request records are per-conversation but not critical for UI
        // No explicit deletion needed here.
    }

    /// Builds an `AgentTurnRecord` by aggregating data from multiple sources.
    private func aggregateTurnRecord(
        turnID: UUID,
        conversationID: UUID,
        store: AgentTurnRecordStore,
        messages: [LumiChatMessage]
    ) async -> AgentTurnRecord {
        // Timestamps from LLM request records
        let startedAt = await store.fetchTurnStartedAt(turnID: turnID) ?? Date()
        let endedAt = await store.fetchTurnEndedAt(turnID: turnID)

        // Token statistics from messages
        var inputTokens = 0
        var outputTokens = 0
        var triggerMessageID: UUID?
        for message in messages where message.turnID == turnID {
            inputTokens += message.inputTokenCount ?? 0
            outputTokens += message.outputTokenCount ?? 0
            if message.role == .user && triggerMessageID == nil {
                triggerMessageID = message.id
            }
        }

        // Tool call statistics
        var toolCallCount = 0
        var toolCallCompletedCount = 0
        if let toolManager = kernel?.toolManager {
            let toolCalls = await toolManager.toolCalls(for: turnID)
            toolCallCount = toolCalls.count
            toolCallCompletedCount = toolCalls.filter { $0.completedAt != nil }.count
        }

        // State: overlay live state for active turns, otherwise derive
        let state: AgentTurnState
        if let liveState = turnStates[conversationID],
           turnIDs[conversationID] == turnID {
            state = liveState
        } else {
            // Completed if we have endedAt; otherwise idle (legacy/unknown)
            state = endedAt != nil ? .completed : .idle
        }

        // Parent turn ID
        let parentTurnID = parentConversationIDs[conversationID].flatMap { _ in
            // If this conversation was created by a parent turn, we could track it
            // For now, return nil unless we have explicit tracking
            nil as UUID?
        }

        return AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            parentTurnID: parentTurnID,
            triggerMessageID: triggerMessageID,
            state: state,
            startedAt: startedAt,
            endedAt: endedAt,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            toolCallCount: toolCallCount,
            toolCallCompletedCount: toolCallCompletedCount,
            title: nil,
            errorMessage: nil
        )
    }

    private func executeTurnLoop(conversationID: UUID) async {
        let turnID = turnIDs[conversationID]
        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            guard let kernel else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)kernel 为 nil，turn 结束")
                }
                failedConversations.insert(conversationID)
                return
            }

            // Resume any incomplete tool-call batch before asking the LLM for a
            // new response. A single assistant message may contain multiple
            // calls, and a suspended call leaves later calls without results.
            if let pendingAssistantMessage = incompleteToolCallMessage(in: conversationID) {
                let suspended = await executePendingToolCalls(
                    in: pendingAssistantMessage,
                    conversationID: conversationID
                )
                if suspended {
                    return
                }
                continue
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)开始 LLM 调用...")
            }

            // Build request with current message history
            let history = kernel.messageManager?.messages(for: conversationID) ?? []
            let tools = (kernel.toolManager?.allAgentTools() ?? []).filter {
                !turnCreationExcludedToolNames[conversationID, default: []].contains($0.name)
            }

            guard let provider = kernel.llmProvider?.allLLMProviders().first else {
                Self.logger.error("\(Self.t)没有可用的 LLM Provider")

                appendErrorMessage(
                    conversationID: conversationID,
                    content: String(localized: "No LLM provider available", defaultValue: "No LLM provider available")
                )
                failedConversations.insert(conversationID)
                return
            }

            let targetProvider: any LumiLLMProvider
            if let conversationProviderID = kernel.conversations?.providerID(for: conversationID),
               let conversationProvider = kernel.llmProvider?.llmProvider(id: conversationProviderID) {
                targetProvider = conversationProvider
            } else if let selectedProviderID = kernel.llmProvider?.selectedProviderID,
                      let selectedProvider = kernel.llmProvider?.llmProvider(id: selectedProviderID) {
                targetProvider = selectedProvider
            } else {
                targetProvider = provider
            }

            let model = kernel.conversations?.modelName(for: conversationID)
                ?? kernel.llmProvider?.selectedModel
                ?? type(of: targetProvider).info.defaultModel

            // 抽取最近一条 user message 的图片附件(由 MessageSender 写入 metadata["imageAttachments"])。
            // 实现细节见 LumiKernel.LumiImageAttachmentMetadata.extract。
            let pendingImages = LumiImageAttachmentMetadata.extract(from: history)

            // 抽取最近一条 user message 的文件附件(由 MessageSender 写入 metadata["fileAttachments"])。
            // 文本类文件正文在下游 MessageBridge 注入用户消息文本。
            let pendingFiles = LumiFileAttachmentMetadata.extract(from: history)

            // 调用所有插件的 willSendToLLM 钩子,让插件可注入/修改 system prompt 等内容。
            // 钩子按插件 order 升序串行执行,每个插件拿到上一个插件处理后的 messages。
            var preparedMessages = history
            for plugin in kernel.pluginManager.allPlugins {
                guard plugin.policy.shouldRegister else { continue }
                preparedMessages = await plugin.willSendToLLM(kernel: kernel, messages: preparedMessages)
            }

            // 拼接策略:把所有插件注入的 system 消息合并为单条,放在 messages 首位,
            // 以最大化 LLM provider 的 prompt cache 命中率。
            let systemFragments = preparedMessages.filter { $0.role == .system }.map(\.content)
            if !systemFragments.isEmpty {
                let mergedSystem = systemFragments.joined(separator: "\n\n")
                let nonSystem = preparedMessages.filter { $0.role != .system }
                let systemMessage = LumiChatMessage(
                    conversationID: conversationID,
                    role: .system,
                    content: mergedSystem
                )
                preparedMessages = [systemMessage] + nonSystem
            }

            let request = LumiLLMRequest(
                messages: preparedMessages,
                model: model,
                tools: tools,
                imageAttachments: pendingImages,
                fileAttachments: pendingFiles,
                generationOptions: LumiLLMGenerationOptions(
                    reasoningEffort: type(of: targetProvider).info.modelCapabilities[model]?.supportsReasoningEffort == true
                        ? kernel.conversations?.reasoningEffort(for: conversationID)
                        : nil
                )
            )

            // 记录本次发出的请求到磁盘(SwiftData),用于设置界面回看。
            let providerID = type(of: targetProvider).info.id
            await AgentTurnRunnerRecordStoreBridge.shared.store?.record(
                request: request,
                conversationID: conversationID,
                turnID: turnID,
                providerID: providerID
            )

            // Call LLM
            // 流式输出:runner 调 kernel.messageStreaming (store) 写临时行,UI 读 store 渲染。
            // 临时行用进程级稳定 id(LumiStreamingRowID),与最终落库行 id 永不冲突——
            // 故最终消息无需对齐临时行 id,直接落库即可;落库后清掉 store 的临时行,
            // UI 的 messagesDidChange 会刷新出真实行(两次独立 diff,无需协调)。
            //
            // 每一轮 LLM 调用前 insert 一条 status:第一轮覆盖 sender 的"正在发送…"
            // (同会话只保留最新),后续轮次(工具结果发回 LLM)补上"正在思考…"指示。
            // 流式 thinking/generating 阶段由 RowBuilder 剔除 status,改由流式行承载。
            insertStatusMessage(
                conversationID: conversationID,
                content: String(localized: "status.thinking", defaultValue: "正在思考…")
            )
            let streamingStore = kernel.messageStreaming
            await streamingStore?.startStreaming(conversationID: conversationID)
            var assistantMessage: LumiChatMessage
            do {
                // onChunk 在 provider 后台任务里调用(@Sendable)。store 的写方法标 async,
                // 通过 await 跳回 @MainActor 执行,保证对 @Published 的写安全。
                // tool-call 增量不通过 onChunk 推送,此处无需处理;最终落库消息会带上完整 toolCalls。
                assistantMessage = try await targetProvider.sendStreaming(request) { chunk in
                    let piece = chunk.content ?? ""
                    if chunk.isThinking {
                        await streamingStore?.appendThinking(piece, conversationID: conversationID)
                    } else {
                        await streamingStore?.appendContent(piece, conversationID: conversationID)
                    }
                }
            } catch {
                Self.logger.error("\(Self.t)LLM 调用失败: \(error.localizedDescription)")
                // 流式期间 store 已持有临时行;失败时清掉它,避免 UI 残留空行。
                await streamingStore?.endStreaming(conversationID: conversationID)
                let disposition = targetProvider.retryDisposition(
                    for: error,
                    context: LumiLLMRetryContext(attempt: 1, maxAttempts: 1)
                )
                var errorMessage = targetProvider.makeErrorMessage(
                    conversationID: conversationID,
                    request: request,
                    error: error,
                    disposition: disposition
                )
                errorMessage.turnID = turnID
                kernel.messageManager?.insertMessage(errorMessage, to: conversationID)
                postMessageSavedNotification(message: errorMessage, conversationID: conversationID)
                failedConversations.insert(conversationID)
                return
            }

            // Resolve user-facing descriptions before persisting the assistant message.
            // The UI must not need to look up tools or execute tool formatting logic.
            assistantMessage.turnID = turnID
            if let toolManager = kernel.toolManager,
               let toolCalls = assistantMessage.toolCalls {
                assistantMessage.toolCalls = toolCalls.map { toolCall in
                    var enriched = toolCall
                    enriched.displayDescription = toolManager.displayDescription(for: toolCall)
                    return enriched
                }
            }

            // Append assistant message to history.
            // 直接落库(无需重建对齐 id):临时行用独立稳定 id,落库行用 provider 生成的随机 id,
            // 两者互不干扰。落库后清掉 store 的临时行,UI 自然从 messagesDidChange 刷新出真实行。
            kernel.messageManager?.insertMessage(assistantMessage, to: conversationID)
            postMessageSavedNotification(message: assistantMessage, conversationID: conversationID)
            await streamingStore?.endStreaming(conversationID: conversationID)

            // No tool calls → turn complete
            guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)无 toolCalls，turn 结束")
                }
                return
            }

            // Execute the entire initial batch in order. Suspended calls are
            // recorded and later answered independently; the batch only
            // becomes eligible for a new LLM request after every call is
            // terminal.
            var batchSuspensions: [String: AgentTurnSuspension] = [:]
            for toolCall in toolCalls where toolCall.result == nil {
                try? Task.checkCancellation()

                if cancelledConversations.contains(conversationID) {
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(Self.t)执行工具: \(toolCall.name)")
                }

                // 流式已结束(endStreaming),工具执行期间没有流式行 —— insert 一条
                // 瞬时 status("正在执行: X…")让 UI 有进度指示。工具结果(tool 消息)
                // insert 时 MessageManager 自动清除此 status;下一个工具再 insert 新的。
                insertStatusMessage(
                    conversationID: conversationID,
                    content: String(
                        localized: "status.executing-tool",
                        defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                    )
                )

                // Execute tool
                guard let toolManager = kernel.toolManager else {
                    Self.logger.error("\(Self.t)ToolManager 不可用")
                    continue
                }

                var result = await toolManager.execute(
                    toolCall,
                    conversationID: conversationID,
                    turnID: turnID
                )
                // Tool implementations do not receive the outer tool-call ID.
                // Bind it here before persisting a suspension so a system-owned
                // child completion can resume the exact parent tool call.
                if case let .suspend(suspension) = result.turnControl,
                   suspension.toolCallID == nil {
                    let boundSuspension = AgentTurnSuspension(
                        suspensionID: suspension.suspensionID,
                        conversationID: suspension.conversationID,
                        toolCallID: toolCall.id,
                        kind: suspension.kind,
                        payload: suspension.payload
                    )
                    result = LumiToolResult(
                        content: result.content,
                        duration: result.duration,
                        isError: result.isError,
                        imageAttachments: result.imageAttachments,
                        turnControl: .suspend(boundSuspension)
                    )
                }

                // Update the assistant message's toolCall with the result
                // This allows the UI to show correct visual state (success/failure/duration)
                kernel.messageManager?.updateToolCallResult(
                    result,
                    toolCallID: toolCall.id,
                    assistantMessageID: assistantMessage.id,
                    in: conversationID
                )

                // Insert tool result as a new message so LLM can see it in the next turn.
                // Encode any tool-result images into metadata["imageAttachments"] so that
                // (a) the model receives them on the next turn (MessageBridge attaches them),
                // and (b) the .tool bubble can render them. Previously the images were dropped.
                let toolMetadata = LumiImageAttachmentMetadata.encode(result.imageAttachments)
                let toolResultMessage = LumiChatMessage(
                    conversationID: conversationID,
                    role: .tool,
                    content: result.content,
                    turnID: turnID,
                    isError: result.isError,
                    metadata: toolMetadata,
                    toolCallID: toolCall.id
                )
                kernel.messageManager?.insertMessage(toolResultMessage, to: conversationID)
                postMessageSavedNotification(message: toolResultMessage, conversationID: conversationID)

                if Self.verbose {
                    Self.logger.info("\(Self.t)工具执行完成: \(toolCall.name), isError=\(result.isError)")
                }

                // 工具通过结构化控制信号请求暂停：写入当前 suspension，
                // 当前批次中尚未执行的调用由恢复路径继续处理。
                if case let .suspend(suspension) = result.turnControl {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)工具请求暂停（\(toolCall.name)），等待外部恢复")
                    }
                    batchSuspensions[toolCall.id] = suspension
                }
            }

            if !batchSuspensions.isEmpty {
                pendingSuspensions[conversationID] = batchSuspensions
                suspensions[conversationID] = batchSuspensions.values.first
                awaitingConversations.insert(conversationID)
                return
            }

            // Continue loop with new tool results in message history
        }
    }
}
