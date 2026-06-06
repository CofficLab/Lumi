import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import SuperLogKit
import os

/// LLM 消息发送服务：流式请求、重试、后置管线回调。
enum SenderService: SuperLog {
    nonisolated static let emoji = "📬"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")

    @MainActor
    static func send(
        request: LLMSendRequest,
        dependencies: LLMSendDependencies
    ) async -> LLMRequestResult {
        let messagesForLLM = composeMessagesForLLM(
            conversationId: request.conversationId,
            baseMessages: request.messages,
            additionalSystemPrompts: request.additionalSystemPrompts
        )

        let toolsArg = dependencies.prepareTools()
        let config = dependencies.resolveRequestConfig(
            request.conversationId,
            messagesForLLM,
            toolsArg != nil
        )

        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await dependencies.applyStreamChunk(request.conversationId, chunk)
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(request.conversationId))] ④ [MessageSender] 流式请求 provider=\(config.providerId) model=\(config.model) messages=\(messagesForLLM.count) tools=\(toolsArg?.count ?? 0)")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let metadataHolder = MetadataHolder()
        let onRequestStart: @Sendable (HTTPRequestMetadata) async -> Void = { metadata in
            await metadataHolder.set(metadata)
                await dependencies.setStatus(
                    request.conversationId,
                    "正在发送消息，大小：\(metadata.formattedBodySize)"
                )
        }

        var lastError: Error?

        for attempt in 1 ... dependencies.retryPolicy.maxRetries {
            if Task.isCancelled {
                return await handleCancelled(
                    conversationId: request.conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime,
                    dependencies: dependencies
                )
            }

            do {
                updateStatusBeforeRequest(
                    conversationId: request.conversationId,
                    attempt: attempt,
                    retryPolicy: dependencies.retryPolicy,
                    setStatus: dependencies.setStatus
                )

                let assistantMessage = try await dependencies.sendStreamingMessage(
                    messagesForLLM,
                    config,
                    toolsArg,
                    onStreamChunk,
                    onRequestStart
                )

                if let metadata = await metadataHolder.get() {
                    await dependencies.runPostPipeline(
                        metadata,
                        assistantMessage,
                        nil,
                        CFAbsoluteTimeGetCurrent() - startTime
                    )
                }

                return .success(assistantMessage)

            } catch LLMServiceError.cancelled {
                return await handleCancelled(
                    conversationId: request.conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime,
                    dependencies: dependencies
                )

            } catch {
                lastError = error

                let statusCode = Self.extractStatusCode(from: error)
                let decision = dependencies.resolveRetryDecision(
                    request.conversationId,
                    error,
                    statusCode,
                    attempt
                )
                guard decision.shouldRetry else {
                    break
                }

                let delay = decision.delaySeconds ?? dependencies.retryPolicy.delay(for: attempt)
                dependencies.logInfo(
                    "\(Self.t)⚠️ 流式请求失败（第 \(attempt) 次），\(Int(delay)) 秒后重试：\(error.localizedDescription)"
                )
                dependencies.setStatus(
                    request.conversationId,
                    "请求失败，\(Int(delay)) 秒后重试 (\(attempt + 1)/\(dependencies.retryPolicy.maxRetries))…"
                )

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return .cancelled
                }
            }
        }

        guard let error = lastError else { return .cancelled }

        dependencies.logError("\(Self.t)请求模型最终失败：\(error.localizedDescription)")

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
            await dependencies.runPostPipeline(
                mutableMetadata,
                nil,
                error,
                mutableMetadata.duration ?? 0
            )
        }

        return .failed(error)
    }

    // MARK: - Private

    private static func composeMessagesForLLM(
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

    @MainActor
    private static func updateStatusBeforeRequest(
        conversationId: UUID,
        attempt: Int,
        retryPolicy: StreamRetryPolicy,
        setStatus: @MainActor (UUID, String) -> Void
    ) {
        if attempt == 1 {
            setStatus(conversationId, "正在发送消息…")
        } else {
            setStatus(conversationId, "正在重试 (\(attempt)/\(retryPolicy.maxRetries))…")
        }
    }

    @MainActor
    private static func handleCancelled(
        conversationId: UUID,
        metadataHolder: MetadataHolder,
        startTime: CFAbsoluteTime,
        dependencies: LLMSendDependencies
    ) async -> LLMRequestResult {
        dependencies.logInfo("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
        dependencies.setStatus(conversationId, "已停止生成")

        if let metadata = await metadataHolder.get() {
            await dependencies.runPostPipeline(
                metadata,
                nil,
                LLMServiceError.cancelled,
                CFAbsoluteTimeGetCurrent() - startTime
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
