import Foundation
import LumiKernel
import os
import SuperLogKit

/// Implementation of `AgentTurnRunning` that executes a full agent turn.
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
public final class AgentTurnRunner: AgentTurnRunning, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    public nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    // MARK: - Properties

    private weak var kernel: LumiKernel?
    private var activeTurnTasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledConversations: Set<UUID> = []
    /// 因工具返回 pending（如 ask_user 等待用户回答）而暂停的对话。
    ///
    /// `executeTurnLoop` 检测到 pending 结果后写入此集合并退出循环，
    /// `runTurn` 据此返回 `.awaitingUserResponse`。与 `cancelledConversations` 互斥：
    /// 取消判断在前，已暂停的对话被取消时优先返回 `.cancelled`。
    private var awaitingConversations: Set<UUID> = []

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)AgentTurnRunnerService")
        }
    }

    // MARK: - AgentTurnRunning

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
            await postTurnFinishedNotification(conversationID: conversationID, reason: .cancelled)
            return .cancelled
        }

        // pending 工具结果（如 ask_user）：turn 暂停，等待用户回答后再恢复。
        if awaitingConversations.contains(conversationID) {
            awaitingConversations.remove(conversationID)
            await postTurnFinishedNotification(conversationID: conversationID, reason: .awaitingUserResponse)
            return .awaitingUserResponse
        }

        await postTurnCompletedNotification(conversationID: conversationID)
        return .completed
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancelTurn ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        cancelledConversations.insert(conversationID)
        activeTurnTasks[conversationID]?.cancel()
        activeTurnTasks.removeValue(forKey: conversationID)
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        activeTurnTasks[conversationID] != nil
    }

    // MARK: - Turn Loop

    private func executeTurnLoop(conversationID: UUID) async {
        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            guard let kernel else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)kernel 为 nil，turn 结束")
                }
                return
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)开始 LLM 调用...")
            }

            // Build request with current message history
            let history = kernel.messageManager?.messages(for: conversationID) ?? []
            let tools = kernel.toolManager?.allAgentTools() ?? []

            guard let provider = kernel.llmProvider?.allLLMProviders().first else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)没有可用的 LLM Provider")
                }
                appendErrorMessage(conversationID: conversationID, content: "No LLM provider available")
                return
            }

            let model = kernel.llmProvider?.selectedModel ?? type(of: provider).info.defaultModel

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
                fileAttachments: pendingFiles
            )

            // Call LLM
            let assistantMessage: LumiChatMessage
            do {
                assistantMessage = try await kernel.llmProvider!.sendToSelectedProvider(request)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)LLM 调用失败: \(error.localizedDescription)")
                }
                appendErrorMessage(conversationID: conversationID, content: error.localizedDescription)
                return
            }

            // Append assistant message to history
            kernel.messageManager?.insertMessage(assistantMessage, to: conversationID)
            postMessageSavedNotification(message: assistantMessage, conversationID: conversationID)

            if Self.verbose {
                Self.logger.info("\(Self.t)收到 assistant 消息, toolCalls=\(assistantMessage.toolCalls?.count ?? 0)")
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

                let result = await toolManager.execute(toolCall, conversationID: conversationID)

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

                // 工具返回 pending（如 ask_user 等待用户回答）：写入 pending 结果后暂停循环，
                // 不再执行后续 toolCall，runTurn 据此返回 .awaitingUserResponse。
                // 恢复时机由对应插件（如 AskUserAnswerObserver）回写答案后再次调用 runTurn。
                if LumiAskUserMarkers.isPendingResponse(result.content) {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)检测到 pending 工具结果（\(toolCall.name)），暂停 turn 等待用户响应")
                    }
                    awaitingConversations.insert(conversationID)
                    return
                }
            }

            // Continue loop with new tool results in message history
        }
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
}
