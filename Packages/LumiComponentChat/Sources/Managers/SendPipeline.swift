import Foundation
import LumiComponentAgentTool
import LumiComponentLLMProvider
import LumiComponentMessage
import LumiComponentPlugin
import LumiComponentTurn

/// Manages the send queue, pending messages, and tool approval.
@MainActor
final class SendPipeline {
    private weak var service: ChatService?

    init(service: ChatService) {
        self.service = service
    }

    // MARK: - State

    func isSending(for conversationID: UUID?) -> Bool {
        guard let conversationID = conversationID ?? service?.selectedConversationID else {
            return false
        }
        return service?.sendingConversationIDs.contains(conversationID) ?? false
    }

    private var turnStartTimeByConversationID: [UUID: Date] = [:]

    private func markTurnStart(_ conversationID: UUID) {
        turnStartTimeByConversationID[conversationID] = Date()
    }

    private func takeTurnDurationMs(for conversationID: UUID) -> Int? {
        guard let start = turnStartTimeByConversationID[conversationID] else { return nil }
        let duration = Date().timeIntervalSince(start) * 1000
        turnStartTimeByConversationID.removeValue(forKey: conversationID)
        return Int(duration.rounded())
    }

    // MARK: - Enqueue

    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {
        guard let service else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !imageAttachments.isEmpty else {
            return
        }

        let targetID = conversationID ?? service.selectedConversationID ?? service.createConversation(title: nil)
        if service.selectedConversationID != targetID {
            service.selectConversation(id: targetID)
        }

        service.pendingMessages.append(
            LumiPendingMessage(
                conversationID: targetID,
                content: trimmed,
                imageAttachments: imageAttachments
            )
        )
        attemptBeginNextSend()
    }

    // MARK: - Tool Approval

    func approvePendingTool() {
        resolvePendingToolApproval(approved: true)
    }

    func rejectPendingTool() {
        resolvePendingToolApproval(approved: false)
    }

    /// Resume 挂起的工具审批（若存在）并清空所有相关状态。
    ///
    /// 三条路径复用：approve / reject / cancel。
    /// resume-once 由「resume 后立即置 nil」保证——`SendPipeline` 与 `ChatService` 均为
    /// `@MainActor`，continuation 的读写在 main actor 上串行，不会发生双重 resume。
    private func resolvePendingToolApproval(approved: Bool) {
        guard let service else { return }
        service.toolApprovalContinuation?.resume(returning: approved)
        service.toolApprovalContinuation = nil
        service.pendingToolConfirmation = nil
    }

    func requestToolApproval(
        conversationID: UUID,
        toolCall: LumiToolCall,
        displayDescription: String
    ) async -> Bool {
        guard let service else { return false }

        // `withCheckedContinuation` 不响应 task cancellation——若调用方直接 `task.cancel()`
        // 而未走 `cancelSending`，continuation 会泄漏、await 永久挂起。
        // 这里用 `withTaskCancellationHandler` 兜底：task 取消时把挂起的审批当作「拒绝」resume 掉。
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // cancellation handler 与本闭包的执行顺序未定义：
                // 若 handler 先跑（已 resume 并置 nil），这里就不能再把已 resume 的
                // continuation 赋回去，否则下一次 resume 会触发 fatal error。赋值前判空。
                guard service.toolApprovalContinuation == nil else { return }
                service.toolApprovalContinuation = continuation
                service.pendingToolConfirmation = LumiPendingToolConfirmation(
                    conversationID: conversationID,
                    toolCall: toolCall,
                    displayDescription: displayDescription
                )
                service.revision += 1
            }
        } onCancel: { [weak service] in
            // onCancel 在取消 task 的线程上同步执行（可能非 MainActor），需 hop 回 MainActor。
            Task { @MainActor [weak service] in
                service?.toolApprovalContinuation?.resume(returning: false)
                service?.toolApprovalContinuation = nil
            }
        }
    }

    // MARK: - Cancel

    func cancelSending(for conversationID: UUID?) {
        guard let service else { return }
        let targetID = conversationID ?? service.selectedConversationID
        guard let targetID else { return }

        // 取消前先把挂起的工具审批当作「拒绝」resume 掉。
        // `withCheckedContinuation` 不响应 cancellation——若不主动 resume，
        // `await requestToolApproval` 会永久挂起，turn 的 `defer` 永不执行 → 死锁。
        // 仅处理属于本会话的审批，避免误伤其他会话挂起的审批。
        if service.pendingToolConfirmation?.conversationID == targetID {
            resolvePendingToolApproval(approved: false)
        }

        service.activeTasksByConversationID[targetID]?.cancel()
        service.activeTasksByConversationID[targetID] = nil
        service.sendingConversationIDs.remove(targetID)
        service.statusState.setStatus(conversationID: targetID, content: "已停止生成")
        service.statusState.clearStatus(conversationID: targetID)
        service.revision += 1
        attemptBeginNextSend()
    }

    // MARK: - Pending Management

    func removePendingMessage(id: UUID) {
        service?.pendingMessages.removeAll { $0.id == id }
        service?.revision += 1
    }

    private func attemptBeginNextSend() {
        guard let service else { return }

        guard let nextIndex = service.pendingMessages.firstIndex(where: { pending in
            service.activeTasksByConversationID[pending.conversationID] == nil
        }) else {
            return
        }

        let pending = service.pendingMessages.remove(at: nextIndex)
        service.revision += 1

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.processPendingSend(pending)
        }
        service.activeTasksByConversationID[pending.conversationID] = task
    }

    // MARK: - Process Send

    func processPendingSend(_ pending: LumiPendingMessage) async {
        guard let service else { return }

        let conversationID = pending.conversationID
        service.sendingConversationIDs.insert(conversationID)
        service.revision += 1

        defer {
            service.activeTasksByConversationID[conversationID] = nil
            service.sendingConversationIDs.remove(conversationID)
            service.statusState.clearStatus(conversationID: conversationID)
            service.revision += 1
            attemptBeginNextSend()
        }

        var userMetadata: [String: String] = [:]
        if !pending.imageAttachments.isEmpty {
            userMetadata["hasImages"] = "true"
            if let encoded = MessageManager.encodeImageAttachments(pending.imageAttachments) {
                userMetadata["imageAttachments"] = encoded
            }
        }

        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: pending.content,
                metadata: userMetadata
            )
        )
        markTurnStart(conversationID)
        service.statusState.setStatus(conversationID: conversationID, content: "正在发送消息…")
        service.revision += 1

        do {
            // per-request：为本次发送构建一份全新的工具集（按当前 context 动态收集插件
            // 工具、内置工具、子 Agent 工具）。贯穿整个 turn 序列，请求结束随局部变量释放。
            // 多个会话因此各自持有独立 ToolService，互不覆盖。
            let toolService = makePerRequestToolService(for: conversationID)
            let outcome = try await service.runAgentTurn(
                conversationID: conversationID,
                toolService: toolService,
                imageAttachments: pending.imageAttachments
            )
            finishTurn(conversationID: conversationID, reason: outcome.turnEndReason)
        } catch is CancellationError {
            finishTurn(conversationID: conversationID, reason: .cancelled)
            return
        } catch {
            service.append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription,
                    isError: true
                )
            )
            finishTurn(conversationID: conversationID, reason: .failed)
        }
    }

    // MARK: - Per-request Tool Set

    /// 为一次发送构建 per-request 工具集。
    ///
    /// 委托给内核的 `AgentToolComponent.buildToolSet`：按当前 context（反映当前项目、
    /// 会话、model 等）收集插件工具，合并内置工具与子 Agent 工具，软去重后返回一份
    /// 全新的 `ToolService`。本次 turn 序列全程持有它，请求结束即释放。
    ///
    /// 兜底：`delegate` 未回填时（理论不应发生——`RootContainer` 创建 LumiCore 后
    /// 立即 `configure`），返回只含内置工具的 ToolService，保证发消息不崩。
    private func makePerRequestToolService(for conversationID: UUID) -> any LumiToolServicing {
        guard let delegate = service?.delegate else {
            return ToolService(tools: ChatService.builtInTools, environment: nil)
        }
        let context = delegate.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            chatSection: .none,
            showsRail: false,
            showsPanelChrome: false,
            isChatSectionVisible: nil,
            additionalDependencies: { _ in }
        )
        return delegate.agentToolComponent.buildToolSet(
            builtInTools: ChatService.builtInTools
        )
    }

    // MARK: - Context & Assistant

    func prepareSendContext(
        _ messages: [LumiChatMessage],
        conversationID: UUID
    ) async -> LumiSendContext {
        guard let service else {
            return LumiSendContext(conversationID: conversationID, messages: messages, currentProjectPath: "", conversationTitle: "", conversationLanguage: .chinese)
        }

        var context = LumiSendContext(
            conversationID: conversationID,
            messages: messages,
            currentProjectPath: service.delegate?.currentProjectPath ?? "",
            conversationTitle: service.conversations.first(where: { $0.id == conversationID })?.title ?? "",
            conversationLanguage: service.language(for: conversationID)
        )
        for middleware in service.middlewares {
            do {
                context = try await middleware.prepare(context)
            } catch {
                break
            }
        }
        return context
    }

    func makeAssistantMessage(
        conversationID: UUID,
        messages: [LumiChatMessage],
        toolService: any LumiToolServicing,
        imageAttachments: [LumiImageAttachment] = []
    ) async throws -> LumiChatMessage {
        guard let service else {
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "Chat core is ready. LLM providers will be connected by plugins."
            )
        }

        let provider = service.providerManager.resolvedProvider(for: conversationID)
        guard let provider else {
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "Chat core is ready. LLM providers will be connected by plugins."
            )
        }

        let providerInfo = type(of: provider).info
        let model = service.providerManager.resolvedModel(for: conversationID, providerInfo: providerInfo)
        // per-request：tools 来自本次 turn 构建的 toolService（按当前 context 动态收集），
        // 而非全局缓存的 service.agentTools。多会话因此各自持有独立工具集。
        let tools = service.automationLevel(for: conversationID).allowsTools ? toolService.tools : []
        let request = LumiLLMRequest(
            messages: MessageManager.messagesWithImageContext(messages, imageAttachments: imageAttachments),
            model: model,
            tools: tools,
            imageAttachments: imageAttachments
        )

        var lastError: Error?
        var lastDisposition = LumiLLMErrorDisposition.nonRetryable
        let maxAttempts = service.llmRetryCount

        for attempt in 0..<maxAttempts {
            try Task.checkCancellation()
            if attempt > 0 {
                service.statusState.setStatus(
                    conversationID: conversationID,
                    content: "重试中（\(attempt + 1)/\(maxAttempts)）..."
                )
                service.revision += 1
            }

            do {
                return try await provider.sendStreaming(request) { [weak service] chunk in
                    await MainActor.run {
                        guard let service else { return }
                        service.statusState.applyStreamChunk(conversationID: conversationID, chunk: chunk)
                        service.revision += 1
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                let context = LumiLLMRetryContext(attempt: attempt + 1, maxAttempts: maxAttempts)
                lastDisposition = provider.retryDisposition(for: error, context: context)
                guard lastDisposition.isRetryable, attempt + 1 < maxAttempts else {
                    break
                }

                let delaySeconds = lastDisposition.retryDelaySeconds ?? pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        if let lastError {
            return provider.makeErrorMessage(
                conversationID: conversationID,
                request: request,
                error: lastError,
                disposition: lastDisposition
            )
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "Request failed.",
            providerID: providerInfo.id,
            modelName: model,
            isError: true
        )
    }


    func continueAgentTurn(conversationID: UUID) async {
        guard let service else { return }

        service.sendingConversationIDs.insert(conversationID)
        service.revision += 1

        defer {
            service.activeTasksByConversationID[conversationID] = nil
            service.sendingConversationIDs.remove(conversationID)
            service.statusState.clearStatus(conversationID: conversationID)
            service.revision += 1
        }

        do {
            // per-request：续聊同样按当前 context 构建本次工具集。
            let toolService = makePerRequestToolService(for: conversationID)
            let outcome = try await service.runAgentTurn(
                conversationID: conversationID,
                toolService: toolService
            )
            finishTurn(conversationID: conversationID, reason: outcome.turnEndReason)
        } catch is CancellationError {
            finishTurn(conversationID: conversationID, reason: .cancelled)
            return
        } catch {
            service.append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription,
                    isError: true
                )
            )
            finishTurn(conversationID: conversationID, reason: .failed)
        }
    }

    func finishTurn(conversationID: UUID, reason: LumiTurnEndReason) {
        // 必须在发通知前清除旧任务条目，否则通过 `lumiTurnFinished` 触发的
        // `continueTurn` 会因 guard `activeTasksByConversationID != nil` 而被静默拒绝。
        service?.activeTasksByConversationID[conversationID] = nil

        if reason == .completed {
            appendTurnCompletedMarker(conversationID: conversationID)
            return
        }

        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: reason.rawValue,
        ]
        // 唯一发送方：`.lumiTurnFinished`（非完成路径）。turn 结束通知统一由 SendPipeline 发送。
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )

        // 调用插件的 turn finished 钩子（异步）
        Task { @MainActor [weak service] in
            await service?.turnFinishedHook?(conversationID, reason)
        }
    }

    func appendTurnCompletedMarker(conversationID: UUID) {
        var metadata: [String: String] = [:]
        if let durationMs = takeTurnDurationMs(for: conversationID) {
            metadata["turnDurationMs"] = "\(durationMs)"
        }

        service?.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: LumiChatMarkers.turnCompleted,
                renderKind: "turn-completed",
                metadata: metadata
            )
        )
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: LumiTurnEndReason.completed.rawValue,
        ]
        // 唯一发送方：`.lumiTurnCompleted`（完成路径）。
        NotificationCenter.default.post(
            name: .lumiTurnCompleted,
            object: nil,
            userInfo: userInfo
        )
        // 唯一发送方：`.lumiTurnFinished`（完成路径，与上面 .lumiTurnCompleted 配对发送）。
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )
    }
}
