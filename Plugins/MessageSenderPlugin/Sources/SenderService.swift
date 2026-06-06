import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import SuperLogKit
import os

/// LLM 消息发送服务：监听 DB 事件、流式请求、写回结果。
@MainActor
final class SenderService: SuperLog {
    nonisolated static let emoji = "📬"
    nonisolated static let verbose: Bool = true

    private weak var plugin: MessageSenderPlugin?
    private var conversationStore: any AgentConversationStore = UnavailableAgentConversationStore()
    private var llmSendService: any LLMSendService = UnavailableLLMSendService()
    private var prepareMessagesForLLM: (UUID, [ChatMessage]) -> [ChatMessage] = { _, messages in messages }
    private var consumeTransientSystemPrompts: (UUID) -> [String] = { _ in [] }
    private var inFlightConversationIds = Set<UUID>()

    nonisolated var logger: Logger { MessageSenderPlugin.logger }

    func configure(plugin: MessageSenderPlugin, runtime: PluginRuntimeContext) {
        self.plugin = plugin
        if let store = runtime.agentConversationStore {
            conversationStore = store
        }
        if let service = runtime.llmSendService {
            llmSendService = service
        }
        prepareMessagesForLLM = runtime.prepareMessagesForLLM
        consumeTransientSystemPrompts = runtime.consumeTransientSystemPrompts
    }

    func handleMessageSaved(conversationId: UUID) {
        if inFlightConversationIds.contains(conversationId) {
            if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: inFlight")
            }
            return
        }

        let phase = conversationStore.loadTurnPhase(for: conversationId)
        guard phase == .processing else {
            if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: phase=\(phase.rawValue)")
            }
            return
        }

        let messages = conversationStore.loadMessages(for: conversationId)
        guard AgentTurnDerivation.shouldRequestLLM(messages: messages) else {
            if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: shouldRequestLLM=false")
            }
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] 开始 LLM 请求 messages=\(messages.count)")
        }
        Task {
            await performSend(conversationId: conversationId, storageMessages: messages)
        }
    }

    private func performSend(conversationId: UUID, storageMessages: [ChatMessage]) async {
        inFlightConversationIds.insert(conversationId)
        defer { inFlightConversationIds.remove(conversationId) }

        let pruned = prepareMessagesForLLM(conversationId, storageMessages)
        let systemPrompts = consumeTransientSystemPrompts(conversationId)
        let request = LLMSendRequest(
            conversationId: conversationId,
            messages: pruned,
            additionalSystemPrompts: systemPrompts
        )

        let result = await send(request: request)

        switch result {
        case let .success(assistantMessage):
            let toolCount = assistantMessage.toolCalls?.count ?? 0
            if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 成功 toolCalls=\(toolCount) → saveMessage")
            }
            conversationStore.saveMessage(assistantMessage, conversationId: conversationId)

        case .cancelled:
            if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 已取消")
            }

        case let .failed(errorMessage):
            if AgentSendPipelineLog.enabled {
                let summary = errorMessage.rawErrorDetail ?? errorMessage.content
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 失败: \(summary) → saveMessage")
            }
            conversationStore.saveMessage(errorMessage, conversationId: conversationId)
        }
    }

    private func send(request: LLMSendRequest) async -> LLMRequestResult {
        let messagesForLLM = composeMessagesForLLM(
            conversationId: request.conversationId,
            baseMessages: request.messages,
            additionalSystemPrompts: request.additionalSystemPrompts
        )

        let toolsArg = llmSendService.prepareTools()
        let config = llmSendService.resolveLLMConfig(
            for: request.conversationId,
            messages: messagesForLLM,
            allowsTools: toolsArg != nil
        )

        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { [llmSendService, conversationId = request.conversationId] chunk in
            await MainActor.run {
                llmSendService.applyStreamChunk(conversationId: conversationId, chunk: chunk)
            }
        }

        if Self.verbose {
            logger.info("\(Self.t)流式请求 provider=\(config.providerId) model=\(config.model) messages=\(messagesForLLM.count) tools=\(toolsArg?.count ?? 0)")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let metadataHolder = MetadataHolder()
        let onRequestStart: @Sendable (HTTPRequestMetadata) async -> Void = { [llmSendService, conversationId = request.conversationId] metadata in
            await metadataHolder.set(metadata)
            await MainActor.run {
                llmSendService.setStatus(
                    conversationId: conversationId,
                    content: "正在发送消息，大小：\(metadata.formattedBodySize)"
                )
            }
        }

        var lastError: Error?

        for attempt in 1 ... llmSendService.retryPolicy.maxRetries {
            if Task.isCancelled {
                return await handleCancelled(
                    conversationId: request.conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime
                )
            }

            do {
                updateStatusBeforeRequest(
                    conversationId: request.conversationId,
                    attempt: attempt,
                    retryPolicy: llmSendService.retryPolicy
                )

                let assistantMessage = try await llmSendService.streamLLMMessage(
                    messages: messagesForLLM,
                    config: config,
                    tools: toolsArg,
                    onChunk: onStreamChunk,
                    onRequestStart: onRequestStart
                )

                if let metadata = await metadataHolder.get() {
                    await llmSendService.runPostPipeline(
                        metadata: metadata,
                        response: assistantMessage,
                        error: nil,
                        duration: CFAbsoluteTimeGetCurrent() - startTime
                    )
                }

                return .success(assistantMessage)

            } catch LLMServiceError.cancelled {
                return await handleCancelled(
                    conversationId: request.conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime
                )

            } catch {
                lastError = error

                let statusCode = Self.extractStatusCode(from: error)
                let decision = llmSendService.resolveRetryDecision(
                    conversationId: request.conversationId,
                    error: error,
                    statusCode: statusCode,
                    attempt: attempt
                )
                guard decision.shouldRetry else {
                    break
                }

                let delay = decision.delaySeconds ?? llmSendService.retryPolicy.delay(for: attempt)
                logger.warning(
                    "\(Self.t)⚠️ 流式请求失败（第 \(attempt) 次），\(Int(delay)) 秒后重试：\(error.localizedDescription)"
                )
                llmSendService.setStatus(
                    conversationId: request.conversationId,
                    content: "请求失败，\(Int(delay)) 秒后重试 (\(attempt + 1)/\(llmSendService.retryPolicy.maxRetries))…"
                )

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return .cancelled
                }
            }
        }

        guard let error = lastError else { return .cancelled }

        logger.error("\(Self.t)请求模型最终失败：\(error.localizedDescription)")

        if let metadata = await metadataHolder.get() {
            var mutableMetadata = metadata
            mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
            mutableMetadata.error = error
            if let llmError = error as? LLMServiceError,
               case let .requestFailed(_, statusCode) = llmError {
                mutableMetadata.responseStatusCode = statusCode
            } else if let apiError = error as? HTTPClientError,
                      case let .httpError(statusCode, _) = apiError {
                mutableMetadata.responseStatusCode = statusCode
            }
            await llmSendService.runPostPipeline(
                metadata: mutableMetadata,
                response: nil,
                error: error,
                duration: mutableMetadata.duration ?? 0
            )
        }

        return .failed(
            llmSendService.buildErrorChatMessage(
                error: error,
                conversationId: request.conversationId,
                providerId: config.providerId,
                rawDetail: error.localizedDescription
            )
        )
    }

    // MARK: - Private

    private func composeMessagesForLLM(
        conversationId: UUID,
        baseMessages: [ChatMessage],
        additionalSystemPrompts: [String]
    ) -> [ChatMessage] {
        guard !additionalSystemPrompts.isEmpty else { return baseMessages }
        guard !baseMessages.isEmpty else { return baseMessages }

        var merged = baseMessages
        let insertionIndex = max(merged.count - 1, 0)
        let transientMessages = additionalSystemPrompts.map {
            ChatMessage(role: .system, conversationId: conversationId, content: $0)
        }
        merged.insert(contentsOf: transientMessages, at: insertionIndex)
        return merged
    }

    private func updateStatusBeforeRequest(
        conversationId: UUID,
        attempt: Int,
        retryPolicy: StreamRetryPolicy
    ) {
        if attempt == 1 {
            llmSendService.setStatus(conversationId: conversationId, content: "正在发送消息…")
        } else {
            llmSendService.setStatus(
                conversationId: conversationId,
                content: "正在重试 (\(attempt)/\(retryPolicy.maxRetries))…"
            )
        }
    }

    private func handleCancelled(
        conversationId: UUID,
        metadataHolder: MetadataHolder,
        startTime: CFAbsoluteTime
    ) async -> LLMRequestResult {
        logger.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
        llmSendService.setStatus(conversationId: conversationId, content: "已停止生成")

        if let metadata = await metadataHolder.get() {
            await llmSendService.runPostPipeline(
                metadata: metadata,
                response: nil,
                error: LLMServiceError.cancelled,
                duration: CFAbsoluteTimeGetCurrent() - startTime
            )
        }

        return .cancelled
    }

    private static func extractStatusCode(from error: Error) -> Int? {
        if let llmError = error as? LLMServiceError,
           case let .requestFailed(_, statusCode) = llmError {
            return statusCode
        }
        if let apiError = error as? HTTPClientError,
           case let .httpError(statusCode, _) = apiError {
            return statusCode
        }
        return nil
    }
}

private actor MetadataHolder {
    private var metadata: HTTPRequestMetadata?

    func set(_ metadata: HTTPRequestMetadata) {
        self.metadata = metadata
    }

    func get() -> HTTPRequestMetadata? {
        metadata
    }
}
