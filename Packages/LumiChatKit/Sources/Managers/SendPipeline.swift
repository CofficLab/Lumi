import Foundation
import LumiCoreKit

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
        guard let service else { return }
        service.pendingToolConfirmation = nil
        service.toolApprovalContinuation?.resume(returning: true)
        service.toolApprovalContinuation = nil
    }

    func rejectPendingTool() {
        guard let service else { return }
        service.pendingToolConfirmation = nil
        service.toolApprovalContinuation?.resume(returning: false)
        service.toolApprovalContinuation = nil
    }

    func requestToolApproval(
        conversationID: UUID,
        toolCall: LumiToolCall,
        displayDescription: String
    ) async -> Bool {
        guard let service else { return false }

        return await withCheckedContinuation { continuation in
            service.toolApprovalContinuation = continuation
            service.pendingToolConfirmation = LumiPendingToolConfirmation(
                conversationID: conversationID,
                toolCall: toolCall,
                displayDescription: displayDescription
            )
            service.revision += 1
        }
    }

    // MARK: - Cancel

    func cancelSending(for conversationID: UUID?) {
        guard let service else { return }
        let targetID = conversationID ?? service.selectedConversationID
        guard let targetID else { return }

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
        service.statusState.setStatus(conversationID: conversationID, content: "正在发送消息…")
        service.revision += 1

        do {
            let outcome = try await service.runAgentTurn(
                conversationID: conversationID,
                imageAttachments: pending.imageAttachments
            )
            if outcome == .completed {
                service.appendTurnCompletedMarker(conversationID: conversationID)
            }
        } catch is CancellationError {
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
        }
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
            currentProjectPath: service.projectPathProvider?.currentProjectPath ?? "",
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
        let tools = service.automationLevel(for: conversationID).allowsTools ? service.agentTools : []
        let request = LumiLLMRequest(
            messages: MessageManager.messagesWithImageContext(messages, imageAttachments: imageAttachments),
            model: model,
            tools: tools,
            imageAttachments: imageAttachments
        )

        var lastError: Error?
        for attempt in 0..<service.llmRetryCount {
            try Task.checkCancellation()
            if attempt > 0 {
                service.statusState.setStatus(
                    conversationID: conversationID,
                    content: "重试中（\(attempt + 1)/\(service.llmRetryCount)）..."
                )
                service.revision += 1
                let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                try await Task.sleep(nanoseconds: delay)
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
            }
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: lastError?.localizedDescription ?? "Request failed.",
            providerID: providerInfo.id,
            modelName: model,
            isError: true,
            rawErrorDetail: lastError?.localizedDescription
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
            let outcome = try await service.runAgentTurn(conversationID: conversationID)
            if outcome == .completed {
                appendTurnCompletedMarker(conversationID: conversationID)
            }
        } catch is CancellationError {
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
        }
    }

    func appendTurnCompletedMarker(conversationID: UUID) {
        service?.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: LumiChatMarkers.turnCompleted,
                renderKind: "turn-completed"
            )
        )
        NotificationCenter.default.post(
            name: .lumiTurnCompleted,
            object: nil,
            userInfo: [LumiMessageSavedNotification.conversationIDKey: conversationID]
        )
    }
}
