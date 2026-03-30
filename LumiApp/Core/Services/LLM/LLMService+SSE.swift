import Foundation
import MagicKit

extension LLMService {
    /// 流式发送消息（SSE），通过 `onChunk` 回调增量内容。
    ///
    /// - Throws: 仅 `LLMServiceError`
    @discardableResult
    func sendStreamingMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]? = nil,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void,
        onRequestStart: @Sendable @escaping (RequestMetadata) async -> Void = { _ in }
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
                AppLogger.core.error("\(self.t)❌ 验证配置失败: \(error.localizedDescription)")
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

        // 构建请求体
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

        // 构建 URLRequest
        let request = provider.buildRequest(url: url, apiKey: config.apiKey)

        let state = StreamingState(startTime: startTime)
        let chunkCounter = ChunkCounter() // 用于调试计数

        do {
            try await llmAPI.sendStreamingRequest(
                request: request,
                body: body,
                onRequestStart: onRequestStart
            ) { chunkData in
                do {
                    try Task.checkCancellation()
                    var shouldContinue = true

                    if Self.verbose >= 2 {
                        let chunkIndex = await chunkCounter.increment()
                        let rawText = String(data: chunkData, encoding: .utf8) ?? "<无法解码>"
                        let preview = rawText.prefix(500) // 限制长度避免日志过长
                        AppLogger.core.debug("\(self.t)📦 [Chunk #\(chunkIndex)] 原始数据 (\(chunkData.count) bytes):\n\(preview)")
                    }

                    let eventData = chunkData

                    if let parsed = try provider.parseStreamChunk(data: eventData) {
                        let rawPayload = String(data: eventData, encoding: .utf8)
                        let chunk = parsed.withRawStreamPayload(rawPayload)

                        if Self.verbose >= 2 {
                            let chunkIndex = await chunkCounter.current()
                            var chunkInfo = "[Chunk #\(chunkIndex)] 解析结果:"
                            if let content = chunk.content {
                                let contentPreview = content.prefix(50)
                                chunkInfo += "\n  📝 内容: \"\(contentPreview)\"\(content.count > 50 ? "..." : "")"
                            }
                            if let eventType = chunk.eventType {
                                chunkInfo += "\n  🏷️ 类型: \(eventType.displayName)"
                            }
                            if let inputTokens = chunk.inputTokens {
                                chunkInfo += "\n  📥 输入tokens: \(inputTokens)"
                            }
                            if let outputTokens = chunk.outputTokens {
                                chunkInfo += "\n  📤 输出tokens: \(outputTokens)"
                            }
                            if let stopReason = chunk.stopReason {
                                chunkInfo += "\n  🛑 停止原因: \(stopReason)"
                            }
                            if chunk.isDone {
                                chunkInfo += "\n  ✅ 已完成"
                            }
                            if let error = chunk.error {
                                chunkInfo += "\n  ❌ 错误: \(error)"
                            }
                            if let toolCalls = chunk.toolCalls, !toolCalls.isEmpty {
                                chunkInfo += "\n  🔧 工具调用: \(toolCalls.count) 个"
                            }
                            AppLogger.core.debug("\(self.t)\(chunkInfo)")
                        }

                        if let content = chunk.content, chunk.eventType == .textDelta {
                            // 记录首个 Token 时间（TTFT）
                            await state.recordFirstToken()
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
                        }
                    } else if Self.verbose >= 1 {
                        let preview = String(data: eventData, encoding: .utf8)?.prefix(100) ?? "无法解码"
                        AppLogger.core.warning("\(self.t)警告：Provider 返回 nil，原始数据：\(preview)...")
                    }

                    return shouldContinue
                } catch {
                    if Self.verbose >= 1 {
                        AppLogger.core.warning("\(self.t)解析流式数据块失败：\(error.localizedDescription)")
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

        // 计算流式传输耗时
        let streamingDuration = await state.getStreamingDuration()

        return ChatMessage(
            role: .assistant,
            conversationId: UUID(),
            content: await state.accumulatedContentChunks.joined(),
            toolCalls: await state.getFinalToolCalls(),
            providerId: config.providerId,
            modelName: config.model,
            latency: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            inputTokens: await state.inputTokens,
            outputTokens: await state.outputTokens,
            totalTokens: await state.totalTokens,
            timeToFirstToken: await state.timeToFirstToken,
            streamingDuration: streamingDuration,
            finishReason: await state.stopReason,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            thinkingContent: await state.getFinalThinking()
        )
    }
}

// MARK: - Chunk Counter (用于并发安全的计数器)

private actor ChunkCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func current() -> Int {
        return count
    }
}
