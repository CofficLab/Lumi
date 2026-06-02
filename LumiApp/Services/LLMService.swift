import Foundation
import AgentToolKit
import LLMKit
import HttpKit

/// LLM 服务
///
/// Lumi 应用的 AI 助手后端服务，负责与各种 LLM 供应商进行通信。
class LLMService: SuperLog, @unchecked Sendable {
    /// 日志标识符
    nonisolated static let emoji = "🤖"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 0

    /// 供同模块扩展使用
    nonisolated let registry: LLMProviderRegistry
    nonisolated let llmAPI: LLMAPIService

    /// 初始化 LLM 服务
    /// - Parameter registry: 供应商注册表（由外部创建并注册所有供应商）
    init(registry: LLMProviderRegistry) {
        self.registry = registry
        self.llmAPI = LLMAPIService()
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)✅ LLM 服务已初始化")
        }
    }

    // MARK: - Provider Queries

    /// 获取所有已注册供应商的信息
    func allProviders() -> [LLMProviderInfo] {
        registry.allProviders()
    }

    /// 根据 ID 查找供应商类型
    func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        registry.providerType(forId: id)
    }

    /// 创建供应商实例
    func createProvider(id: String) -> (any SuperLLMProvider)? {
        registry.createProvider(id: id)
    }

    // MARK: - Local Model Management

    /// 判断当前配置是否为本地供应商且模型未就绪（将触发加载或等待）。
    func needsLocalModelLoad(config: LLMConfig) async -> Bool {
        guard let provider = registry.createProvider(id: config.providerId) as? any SuperLocalLLMProvider else {
            return false
        }
        let state = await provider.getModelState()
        return state != .ready
    }

    /// 确保本地模型已就绪：若为 .loading/.generating 则轮询等待，若为 .idle/.error 则尝试加载，超时或失败则抛出。
    func ensureLocalModelReady(
        local: any SuperLocalLLMProvider,
        modelId: String,
        timeoutSeconds: Double = 300,
        pollIntervalSeconds: Double = 1
    ) async throws {
        var state = await local.getModelState()
        if state == .ready { return }

        if state == .loading || state == .generating {
            let deadline = CFAbsoluteTimeGetCurrent() + timeoutSeconds
            while CFAbsoluteTimeGetCurrent() < deadline {
                do {
                    try Task.checkCancellation()
                } catch is CancellationError {
                    throw LLMServiceError.cancelled
                }
                state = await local.getModelState()
                if state == .ready { return }
                if case .error = state { break }
                do {
                    try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
                } catch is CancellationError {
                    throw LLMServiceError.cancelled
                }
            }
            if state != .ready {
                throw LLMServiceError.requestFailed("加载超时，请稍后重试或到设置中查看")
            }
            return
        }

        do {
            try await local.loadModel(id: modelId)
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        state = await local.getModelState()
        if state != .ready {
            let msg: String
            if case .error(let s) = state { msg = s } else { msg = "模型未就绪" }
            throw LLMServiceError.requestFailed(msg)
        }
    }

    // MARK: - HTTP (非流式请求)

    /// 发送消息到指定的 LLM 供应商（单次 HTTP 请求）。
    ///
    /// - Throws: 仅 `LLMServiceError`
    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [SuperAgentTool]? = nil) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从消息中获取 conversationId
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let provider = registry.createProvider(id: config.providerId) else {
            AppLogger.core.error("\(self.t)未找到供应商：\(config.providerId)")
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage(conversationId: conversationId)
        }

        let isLocal = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocal {
            do {
                try config.validate()
            } catch let error as LLMServiceError {
                // 传递 providerId，以便在 API Key 缺失错误中显示正确的供应商
                return error.toChatMessage(conversationId: conversationId, providerId: config.providerId)
            }
        }

        if let local = provider as? any SuperLocalLLMProvider {
            try await ensureLocalModelReady(local: local, modelId: config.model)
            let images = messages.last(where: { $0.role == .user }).map(\.images) ?? []
            let msg: ChatMessage
            do {
                msg = try await local.sendMessage(
                    messages: messages,
                    model: config.model,
                    tools: tools,
                    systemPrompt: nil,
                    images: images
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
            AppLogger.core.error("\(self.t)无效的 URL: \(baseURLString)")
            return LLMServiceError.invalidBaseURL(baseURLString).toChatMessage(conversationId: conversationId)
        }

        // 构建请求体
        var body: [String: Any]
        do {
            body = try provider.buildRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
            applyGenerationOptions(from: config, to: &body)
        } catch {
            AppLogger.core.error("\(self.t)构建请求体失败：\(error.localizedDescription)")
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        // 构建 URLRequest
        let request = provider.buildRequest(url: url, apiKey: config.apiKey)

        do {
            let data: Data
            do {
                data = try await llmAPI.sendChatRequest(
                    request: request,
                    body: body
                )
            } catch {
                throw LLMServiceError.requestFailed(error.localizedDescription)
            }

            let response = try provider.parseResponseWithMetadata(data: data)
            if response.content.isEmpty,
               response.toolCalls?.isEmpty != false,
               response.thinkingContent?.isEmpty != false {
                throw LLMServiceError.requestFailed("模型响应为空，请检查供应商返回内容、max_tokens 设置或请求日志")
            }

            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000.0

            return ChatMessage(
                role: .assistant, conversationId: conversationId,
                content: response.content,
                toolCalls: response.toolCalls,
                providerId: config.providerId,
                modelName: config.model,
                latency: latency,
                temperature: config.temperature,
                maxTokens: config.maxTokens,
                thinkingContent: response.thinkingContent
            )

        } catch let e as LLMServiceError {
            throw e
        } catch let apiError as HTTPClientError {
            // 传递 HTTP 状态码到 LLMServiceError
            if case let .httpError(statusCode, message) = apiError {
                throw LLMServiceError.requestFailed("[HTTP \(statusCode)] \(message)", statusCode: statusCode)
            } else {
                throw LLMServiceError.requestFailed(apiError.localizedDescription)
            }
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }

    // MARK: - SSE (流式请求)

    /// 流式发送消息（SSE），通过 `onChunk` 回调增量内容。
    ///
    /// - Throws: 仅 `LLMServiceError`
    @discardableResult
    func sendStreamingMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]? = nil,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void,
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in }
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从消息中获取 conversationId
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let provider = registry.createProvider(id: config.providerId) else {
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage(conversationId: conversationId)
        }

        let isLocalStream = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocalStream {
            do {
                try config.validate()
            } catch let error as LLMServiceError {
                AppLogger.core.error("\(self.t)❌ 验证配置失败: \(error.localizedDescription)")
                throw error
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
            return LLMServiceError.invalidBaseURL(baseURLString).toChatMessage(conversationId: conversationId)
        }

        // 构建请求体
        var body: [String: Any]
        do {
            body = try provider.buildStreamingRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
            applyGenerationOptions(from: config, to: &body)
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        // 构建 URLRequest
        let request = provider.buildRequest(url: url, apiKey: config.apiKey)

        let state = StreamingState(startTime: startTime, maxThinkingLength: AgentConfig.maxThinkingTextLength)
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
                                await state.startNewToolCall(
                                    id: firstToolCall.id,
                                    name: firstToolCall.name,
                                    hasPartialJson: hasPartialJson,
                                    arguments: firstToolCall.arguments
                                )
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
        } catch let apiError as HTTPClientError {
            // 传递 HTTP 状态码到 LLMServiceError
            if case let .httpError(statusCode, message) = apiError {
                throw LLMServiceError.requestFailed("[HTTP \(statusCode)] \(message)", statusCode: statusCode)
            } else {
                throw LLMServiceError.requestFailed(apiError.localizedDescription)
            }
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        await state.saveCurrentToolCall()

        if let error = await state.streamError {
            throw LLMServiceError.requestFailed(error)
        }

        let finalContent = await state.accumulatedContentChunks.joined()
        let finalThinking = await state.getFinalThinking()
        let kitToolCalls = await state.getFinalToolCalls()

        if finalContent.isEmpty, finalThinking == nil, kitToolCalls == nil {
            throw LLMServiceError.requestFailed("模型流式响应为空，请检查供应商返回内容、max_tokens 设置或请求日志")
        }

        // 计算流式传输耗时
        let streamingDuration = await state.getStreamingDuration()

        // 桥接 KitToolCall → App ToolCall
        let appToolCalls = kitToolCalls?.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            toolCalls: appToolCalls,
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
            thinkingContent: finalThinking
        )
    }

    private func applyGenerationOptions(from config: LLMConfig, to body: inout [String: Any]) {
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }

        if let maxTokens = config.maxTokens {
            body["max_tokens"] = maxTokens
        }
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

// MARK: - LLMServiceError → ChatMessage

extension LLMServiceError {
    /// 转为可落库消息：使用 `ChatMessage+Error` 中的工厂方法创建错误消息
    /// - Parameter conversationId: 会话 ID
    /// - Parameter providerId: 供应商 ID（可选，用于 API Key 缺失错误）
    func toChatMessage(conversationId: UUID, providerId: String? = nil) -> ChatMessage {
        switch self {
        case .apiKeyEmpty:
            let pid = providerId ?? ""
            return ChatMessage.apiKeyMissingMessage(providerId: pid, conversationId: conversationId)
        case .modelEmpty:
            return ChatMessage.llmModelEmptyMessage(conversationId: conversationId)
        case .providerIdEmpty:
            return ChatMessage.llmProviderIdEmptyMessage(conversationId: conversationId)
        case let .temperatureOutOfRange(v):
            return ChatMessage.llmTemperatureInvalidMessage(temperature: v, conversationId: conversationId)
        case let .maxTokensInvalid(v):
            return ChatMessage.llmMaxTokensInvalidMessage(maxTokens: v, conversationId: conversationId)
        case let .providerNotFound(providerId):
            return ChatMessage.llmProviderNotFoundMessage(providerId: providerId, conversationId: conversationId)
        case let .invalidBaseURL(urlString):
            return ChatMessage.llmInvalidBaseURLMessage(baseURL: urlString, conversationId: conversationId)
        case .cancelled:
            return ChatMessage.cancelledMessage(conversationId: conversationId)
        case let .requestFailed(message, _):
            return ChatMessage.llmRequestFailedMessage(message: message, conversationId: conversationId)
        }
    }
}
