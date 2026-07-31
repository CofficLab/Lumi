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
/// - `.lumiTurnCompleted` when turn ends normally (completed)
/// - `.lumiTurnFinished` when turn ends (any reason)
@MainActor
public final class AgentTurnRunner: AgentTurnManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    public nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - Properties

    private weak var kernel: LumiKernel?
    private var activeTurnTasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledConversations: Set<UUID> = []
    /// 因工具请求用户交互而暂停的对话。
    private var awaitingConversations: Set<UUID> = []
    private var suspensions: [UUID: AgentTurnSuspension] = [:]
    private var turnStates: [UUID: AgentTurnState] = [:]
    private var failedConversations: Set<UUID> = []
    private var pendingChildWorks: [UUID: [String: AgentTurnChildWork]] = [:]
    private var activeChildWorks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)AgentTurnRunnerService")
        }
    }

    // MARK: - AgentTurnManaging

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
        turnStates[conversationID] = .running

        let task = Task { [weak self] in
            guard let self else { return }
            await self.executeTurnLoop(conversationID: conversationID)
        }
        activeTurnTasks[conversationID] = task

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
        let suspension = suspensions[conversationID] ?? persistedSuspension(for: conversationID)
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
        turnStates[conversationID] = .running
        return try await runTurn(in: conversationID)
    }

    @discardableResult
    public func registerChildWork(
        in conversationID: UUID,
        suspensionID: String,
        work: @escaping AgentTurnChildWork
    ) -> Bool {
        pendingChildWorks[conversationID, default: [:]][suspensionID] = work
        return true
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancelTurn ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        cancelledConversations.insert(conversationID)
        suspensions.removeValue(forKey: conversationID)
        pendingChildWorks.removeValue(forKey: conversationID)
        activeChildWorks[conversationID]?.cancel()
        activeChildWorks.removeValue(forKey: conversationID)
        turnStates[conversationID] = .cancelled
        activeTurnTasks[conversationID]?.cancel()
        activeTurnTasks.removeValue(forKey: conversationID)
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        activeTurnTasks[conversationID] != nil
    }

    private func startChildWorkIfNeeded(for conversationID: UUID) {
        guard activeChildWorks[conversationID] == nil,
              let suspension = suspensions[conversationID],
              let work = pendingChildWorks[conversationID]?.removeValue(forKey: suspension.suspensionID)
        else { return }

        if pendingChildWorks[conversationID]?.isEmpty == true {
            pendingChildWorks.removeValue(forKey: conversationID)
        }

        let task = Task { @MainActor [weak self] in
            let answer = await work()
            guard !Task.isCancelled, let self else { return }
            activeChildWorks.removeValue(forKey: conversationID)
            let request = AgentTurnResumeRequest(
                suspensionID: suspension.suspensionID,
                answer: answer
            )
            if let messageSender = self.kernel?.messageSender {
                _ = try? await messageSender.resumeTurn(in: conversationID, request: request)
            } else {
                _ = try? await self.resumeTurn(in: conversationID, request: request)
            }
        }
        activeChildWorks[conversationID] = task
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

    private func executeTurnLoop(conversationID: UUID) async {
        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            guard let kernel else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)kernel 为 nil，turn 结束")
                }
                failedConversations.insert(conversationID)
                return
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)开始 LLM 调用...")
            }

            // Build request with current message history
            let history = kernel.messageManager?.messages(for: conversationID) ?? []
            let tools = kernel.toolManager?.allAgentTools() ?? []
            if Self.verbose {
                let metrics = Self.messageMetrics(history)
                Self.logger.info("\(Self.t)LLM history loaded conversation=\(conversationID.uuidString.prefix(8)) messages=\(history.count) contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars) reasoningChars=\(metrics.reasoningChars) toolCallArgumentChars=\(metrics.toolCallArgumentChars)")
            }

            guard let provider = kernel.llmProvider?.allLLMProviders().first else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)没有可用的 LLM Provider")
                }
                appendErrorMessage(
                    conversationID: conversationID,
                    content: String(localized: "No LLM provider available", defaultValue: "No LLM provider available")
                )
                failedConversations.insert(conversationID)
                return
            }

            let targetProvider: any LumiLLMProvider
            if let selectedProviderID = kernel.llmProvider?.selectedProviderID,
               let selectedProvider = kernel.llmProvider?.llmProvider(id: selectedProviderID) {
                targetProvider = selectedProvider
            } else {
                targetProvider = provider
            }

            let model = kernel.llmProvider?.selectedModel ?? type(of: targetProvider).info.defaultModel

            // 抽取最近一条 user message 的图片附件(由 MessageSender 写入 metadata["imageAttachments"])。
            // 实现细节见 LumiKernel.LumiImageAttachmentMetadata.extract。
            let pendingImages = LumiImageAttachmentMetadata.extract(from: history)

            // 抽取最近一条 user message 的文件附件(由 MessageSender 写入 metadata["fileAttachments"])。
            // 文本类文件正文在下游 MessageBridge 注入用户消息文本。
            let pendingFiles = LumiFileAttachmentMetadata.extract(from: history)
            if Self.verbose {
                let imageBase64Chars = pendingImages.reduce(0) { $0 + $1.base64Data.count }
                let fileBase64Chars = pendingFiles.reduce(0) { $0 + $1.base64Data.count }
                let fileTextChars = pendingFiles.reduce(0) { $0 + ($1.textContent?.count ?? 0) }
                Self.logger.info("\(Self.t)LLM attachments extracted conversation=\(conversationID.uuidString.prefix(8)) images=\(pendingImages.count) imageBase64Chars=\(imageBase64Chars) files=\(pendingFiles.count) fileBase64Chars=\(fileBase64Chars) fileTextChars=\(fileTextChars)")
            }

            // 调用所有插件的 willSendToLLM 钩子,让插件可注入/修改 system prompt 等内容。
            // 钩子按插件 order 升序串行执行,每个插件拿到上一个插件处理后的 messages。
            var preparedMessages = history
            for plugin in kernel.pluginManager.allPlugins {
                guard plugin.policy.shouldRegister else { continue }
                preparedMessages = await plugin.willSendToLLM(kernel: kernel, messages: preparedMessages)
                if Self.verbose {
                    let metrics = Self.messageMetrics(preparedMessages)
                    Self.logger.info("\(Self.t)willSendToLLM plugin=\(plugin.id) messages=\(preparedMessages.count) contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars)")
                }
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
                if Self.verbose {
                    Self.logger.info("\(Self.t)Merged system prompt fragments=\(systemFragments.count) mergedChars=\(mergedSystem.count) nonSystemMessages=\(nonSystem.count)")
                }
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
                providerID: providerID
            )

            // Call LLM
            // 流式输出:runner 调 kernel.messageStreaming (store) 写临时行,UI 读 store 渲染。
            // 临时行用进程级稳定 id(LumiStreamingRowID),与最终落库行 id 永不冲突——
            // 故最终消息无需对齐临时行 id,直接落库即可;落库后清掉 store 的临时行,
            // UI 的 messagesDidChange 会刷新出真实行(两次独立 diff,无需协调)。
            let streamingStore = kernel.messageStreaming
            await streamingStore?.startStreaming(conversationID: conversationID)
            let assistantMessage: LumiChatMessage
            do {
                if Self.verbose {
                    let metrics = Self.messageMetrics(preparedMessages)
                    Self.logger.info("\(Self.t)LLM request start provider=\(type(of: targetProvider).info.id) model=\(model) messages=\(preparedMessages.count) tools=\(tools.count) contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars) reasoningChars=\(metrics.reasoningChars)")
                }
                // onChunk 在 provider 后台任务里调用(@Sendable)。store 的写方法标 async,
                // 通过 await 跳回 @MainActor 执行,保证对 @Published 的写安全。
                // tool-call 增量不通过 onChunk 推送,此处无需处理;最终落库消息会带上完整 toolCalls。
                assistantMessage = try await targetProvider.sendStreaming(request) { chunk in
                    let piece = chunk.content ?? ""
                    if chunk.isThinking {
                        await streamingStore?.appendThinking(piece)
                    } else {
                        await streamingStore?.appendContent(piece)
                    }
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)LLM 调用失败: \(error.localizedDescription)")
                }
                // 流式期间 store 已持有临时行;失败时清掉它,避免 UI 残留空行。
                await streamingStore?.endStreaming()
                let disposition = targetProvider.retryDisposition(
                    for: error,
                    context: LumiLLMRetryContext(attempt: 1, maxAttempts: 1)
                )
                let errorMessage = targetProvider.makeErrorMessage(
                    conversationID: conversationID,
                    request: request,
                    error: error,
                    disposition: disposition
                )
                kernel.messageManager?.insertMessage(errorMessage, to: conversationID)
                postMessageSavedNotification(message: errorMessage, conversationID: conversationID)
                failedConversations.insert(conversationID)
                return
            }

            // Append assistant message to history.
            // 直接落库(无需重建对齐 id):临时行用独立稳定 id,落库行用 provider 生成的随机 id,
            // 两者互不干扰。落库后清掉 store 的临时行,UI 自然从 messagesDidChange 刷新出真实行。
            kernel.messageManager?.insertMessage(assistantMessage, to: conversationID)
            postMessageSavedNotification(message: assistantMessage, conversationID: conversationID)
            await streamingStore?.endStreaming()

            if Self.verbose {
                let toolArgChars = assistantMessage.toolCalls?.reduce(0) { $0 + $1.arguments.count } ?? 0
                Self.logger.info("\(Self.t)收到 assistant 消息 contentChars=\(assistantMessage.content.count) reasoningChars=\(assistantMessage.reasoningContent?.count ?? 0) toolCalls=\(assistantMessage.toolCalls?.count ?? 0) toolCallArgumentChars=\(toolArgChars)")
            }

            // No tool calls → turn complete
            guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)无 toolCalls，turn 结束")
                }
                return
            }

            // Execute each tool call
            for toolCall in toolCalls {
                try? Task.checkCancellation()

                if cancelledConversations.contains(conversationID) {
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(Self.t)执行工具: \(toolCall.name)")
                }

                // Execute tool
                guard let toolManager = kernel.toolManager else {
                    Self.logger.error("\(Self.t)ToolManager 不可用")
                    continue
                }

                var result = await toolManager.execute(toolCall, conversationID: conversationID)
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
                if Self.verbose {
                    let imageBase64Chars = result.imageAttachments.reduce(0) { $0 + $1.base64Data.count }
                    Self.logger.info("\(Self.t)工具结果 received tool=\(toolCall.name) contentChars=\(result.content.count) images=\(result.imageAttachments.count) imageBase64Chars=\(imageBase64Chars) isError=\(result.isError)")
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
                    isError: result.isError,
                    metadata: toolMetadata,
                    toolCallID: toolCall.id
                )
                kernel.messageManager?.insertMessage(toolResultMessage, to: conversationID)
                postMessageSavedNotification(message: toolResultMessage, conversationID: conversationID)

                if Self.verbose {
                    Self.logger.info("\(Self.t)工具执行完成: \(toolCall.name), isError=\(result.isError)")
                }

                // 工具通过结构化控制信号请求暂停：写入 suspension 后停止当前 turn。
                if case let .suspend(suspension) = result.turnControl {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)工具请求暂停（\(toolCall.name)），等待外部恢复")
                    }
                    suspensions[conversationID] = suspension
                    awaitingConversations.insert(conversationID)
                    return
                }
            }

            // Continue loop with new tool results in message history
        }
    }

    /// Rebuilds a suspension from the persisted assistant tool-call result.
    /// This makes a suspended turn recoverable after the manager is recreated.
    private func persistedSuspension(for conversationID: UUID) -> AgentTurnSuspension? {
        let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
        for message in messages.reversed() where message.role == .assistant {
            for toolCall in (message.toolCalls ?? []).reversed() {
                if case let .suspend(suspension) = toolCall.result?.turnControl,
                   suspension.conversationID == conversationID {
                    return suspension
                }
            }
        }
        return nil
    }

    // MARK: - Notifications

    private func postMessageSavedNotification(message: LumiChatMessage, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            "messageID": message.id,
            LumiMessageSavedNotification.roleKey: message.role.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiMessageSaved,
            object: nil,
            userInfo: userInfo
        )
    }

    private func postTurnCompletedNotification(conversationID: UUID) async {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: LumiTurnEndReason.completed.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiTurnCompleted,
            object: nil,
            userInfo: userInfo
        )
        // 复用 finished 路径：发送 .lumiTurnFinished 并分发 onTurnFinished 钩子
        await postTurnFinishedNotification(conversationID: conversationID, reason: .completed)
    }

    private func postTurnFinishedNotification(conversationID: UUID, reason: LumiTurnEndReason) async {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: reason.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )

        // 分发 onTurnFinished 钩子（按插件 order 升序，仅启用插件）。
        // 与上面 willSendToLLM 的遍历模式一致。
        guard let kernel else { return }
        for plugin in kernel.pluginManager.allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            await plugin.onTurnFinished(kernel: kernel, conversationID: conversationID, reason: reason)
        }
    }

    // MARK: - Helpers

    private func appendErrorMessage(conversationID: UUID, content: String) {
        guard let kernel else { return }
        let errorMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: content
        )
        kernel.messageManager?.insertMessage(errorMessage, to: conversationID)
        postMessageSavedNotification(message: errorMessage, conversationID: conversationID)
    }

    private static func messageMetrics(_ messages: [LumiChatMessage]) -> (
        contentChars: Int,
        metadataChars: Int,
        reasoningChars: Int,
        toolCallArgumentChars: Int
    ) {
        var contentChars = 0
        var metadataChars = 0
        var reasoningChars = 0
        var toolCallArgumentChars = 0

        for message in messages {
            contentChars += message.content.count
            metadataChars += message.metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
            reasoningChars += message.reasoningContent?.count ?? 0
            toolCallArgumentChars += message.toolCalls?.reduce(0) { $0 + $1.arguments.count } ?? 0
        }

        return (contentChars, metadataChars, reasoningChars, toolCallArgumentChars)
    }
}
