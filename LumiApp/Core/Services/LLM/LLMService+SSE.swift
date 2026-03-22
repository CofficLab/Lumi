import Foundation
import MagicKit

extension LLMService {
    // MARK: - SSE 流式

    /// 将原始 SSE 数据块拆分为单事件列表。
    /// 兼容「多个 event/data 粘在同一个网络块中、且缺少空行分隔」的非标准实现。
    private nonisolated static func splitSSEEvents(from rawData: Data) -> [Data] {
        guard let text = String(data: rawData, encoding: .utf8) else {
            return [rawData]
        }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var events: [Data] = []
        var currentLines: [String] = []
        var hasDataLine = false

        func flushCurrentEvent() {
            guard !currentLines.isEmpty else { return }
            let payload = currentLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !payload.isEmpty, let data = payload.data(using: .utf8) {
                events.append(data)
            }
            currentLines.removeAll(keepingCapacity: true)
            hasDataLine = false
        }

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty {
                flushCurrentEvent()
                continue
            }
            if line.hasPrefix("event:"), hasDataLine {
                flushCurrentEvent()
            }
            if line.hasPrefix("data:") {
                hasDataLine = true
            }
            currentLines.append(line)
        }

        flushCurrentEvent()
        return events.isEmpty ? [rawData] : events
    }

    /// 流式发送消息（SSE），通过 `onChunk` 回调增量内容。
    ///
    /// - Throws: 仅 `LLMServiceError`
    @discardableResult
    func sendStreamingMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]? = nil,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let provider = registry.createProvider(id: config.providerId) else {
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage()
        }

        let isLocalStream = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocalStream {
            do {
                try config.validate()
            } catch let error as LLMServiceError {
                return error.toChatMessage()
            }
        }

        if let local = provider as? any SuperLocalLLMProvider {
            try await ensureLocalModelReady(local: local, modelId: config.model)
            let images = messages.last(where: { $0.role == .user }).map(\.images) ?? []
            let msg: ChatMessage
            do {
                msg = try await local.streamChat(
                    messages: messages,
                    model: config.model,
                    tools: tools,
                    systemPrompt: nil,
                    images: images,
                    onChunk: onChunk
                )
            } catch let e as LLMServiceError {
                throw e
            } catch is CancellationError {
                throw LLMServiceError.cancelled
            } catch {
                throw LLMServiceError.requestFailed(error.localizedDescription)
            }
            return msg
        }

        let baseURLString = provider.baseURL

        guard let url = URL(string: baseURLString) else {
            return LLMServiceError.invalidBaseURL(baseURLString).toChatMessage()
        }

        let body: [String: Any]
        do {
            body = try provider.buildStreamingRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)🚀 发送流式请求到 \(config.providerId): \(config.model)")
        }

        var additionalHeaders: [String: String] = [:]
        if config.providerId == "zhipu" {
            additionalHeaders["anthropic-version"] = "2023-06-01"
        }

        let state = StreamingState(startTime: startTime)

        do {
            try await llmAPI.sendStreamingRequest(
                url: url,
                apiKey: config.apiKey,
                body: body,
                additionalHeaders: additionalHeaders
            ) { chunkData in
                do {
                    try Task.checkCancellation()
                    var shouldContinue = true

                    for eventData in Self.splitSSEEvents(from: chunkData) {
                        if let parsed = try provider.parseStreamChunk(data: eventData) {
                            let rawPayload = String(data: eventData, encoding: .utf8)
                            let chunk = parsed.withRawStreamPayload(rawPayload)

                            if let content = chunk.content, chunk.eventType == .textDelta {
                                await state.appendContent(content)
                            }
                            
                            if let content = chunk.content, chunk.eventType == .thinkingDelta {
                                await state.appendThinking(content)
                            }

                            if let toolCalls = chunk.toolCalls {
                                await state.saveCurrentToolCall()

                                if let firstToolCall = toolCalls.first {
                                    let hasPartialJson = chunk.partialJson != nil
                                    await state.startNewToolCall(firstToolCall, hasPartialJson: hasPartialJson)
                                }
                            }

                            if let partialJson = chunk.partialJson {
                                await state.appendToolCallArguments(partialJson)
                            }

                            if let error = chunk.error {
                                await state.setError(error)
                            }

                            await state.updateTokens(input: chunk.inputTokens, output: chunk.outputTokens)
                            if let reason = chunk.stopReason {
                                await state.setStopReason(reason)
                            }

                            if chunk.isDone {
                                await state.saveCurrentToolCall()
                            }

                            await onChunk(chunk)

                            if chunk.isDone {
                                shouldContinue = false
                                break
                            }
                        } else if Self.verbose >= 1 {
                            let preview = String(data: eventData, encoding: .utf8)?.prefix(100) ?? "无法解码"
                            AppLogger.core.warning("\(self.t)警告：Provider 返回 nil，原始数据: \(preview)...")
                        }
                    }
                    return shouldContinue
                } catch {
                    if Self.verbose >= 1 {
                        AppLogger.core.warning("\(self.t)解析流式数据块失败: \(error.localizedDescription)")
                    }
                    return true
                }
            }
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch let e as LLMServiceError {
            throw e
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        await state.saveCurrentToolCall()

        if let error = await state.streamError {
            throw LLMServiceError.requestFailed(error)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let latency = (endTime - startTime) * 1000.0
        let finalContent = await state.accumulatedContentChunks.joined()
        let finalThinking = await state.accumulatedThinkingChunks.joined()
        let finalToolCalls = await state.accumulatedToolCalls
        let finalInputTokens = await state.inputTokens
        let finalOutputTokens = await state.outputTokens
        let finalStopReason = await state.stopReason
        let finalTimeToFirstToken = await state.timeToFirstToken

        if Self.verbose >= 1 {
            AppLogger.core.info("\(Self.t)✅ 流式完成，总耗时：\(String(format: "%.2f", latency))ms, TTFT: \(String(format: "%.2f", finalTimeToFirstToken ?? 0))ms, 内容长度：\(finalContent.count)")
        }

        let totalTokens: Int? = if let input = finalInputTokens, let output = finalOutputTokens {
            input + output
        } else {
            nil
        }

        return ChatMessage(
            role: .assistant,
            content: finalContent,
            toolCalls: finalToolCalls.isEmpty ? nil : finalToolCalls,
            providerId: config.providerId,
            modelName: config.model,
            latency: latency,
            inputTokens: finalInputTokens,
            outputTokens: finalOutputTokens,
            totalTokens: totalTokens,
            timeToFirstToken: finalTimeToFirstToken,
            finishReason: finalStopReason,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            thinkingContent: finalThinking.isEmpty ? nil : finalThinking
        )
    }
}
