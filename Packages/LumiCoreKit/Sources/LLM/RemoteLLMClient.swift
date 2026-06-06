import Foundation
import AgentToolKit
import HttpKit
import LLMKit
import LLMProviderKit

/// 远程 LLM 完整发送：消息整理、HTTP/SSE、流式聚合。
public enum RemoteLLMClient {
    public static func sendChat(
        provider: any SuperLLMProvider,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        apiService: LLMAPIService
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let url = URL(string: provider.baseURL) else {
            throw LLMServiceError.invalidBaseURL(provider.baseURL)
        }

        let prepared = provider.prepareMessagesForProvider(messages)
        var body = try provider.buildRequestBody(
            messages: prepared,
            model: config.model,
            tools: tools,
            systemPrompt: ""
        )
        provider.applyGenerationOptions(config: config, model: config.model, to: &body)

        let request = provider.buildRequest(url: url)

        let data: Data
        do {
            data = try await apiService.sendChatRequest(request: request, body: body)
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error, provider: provider)
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        let response = try provider.parseResponseWithMetadata(data: data)
        if response.content.isEmpty,
           response.toolCalls?.isEmpty != false,
           response.thinkingContent?.isEmpty != false {
            throw LLMServiceError.requestFailed("模型响应为空，请检查供应商返回内容、max_tokens 设置或请求日志")
        }

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: response.content,
            toolCalls: response.toolCalls,
            providerId: config.providerId,
            modelName: config.model,
            latency: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            thinkingContent: response.thinkingContent
        )
    }

    public static func streamChat(
        provider: any SuperLLMProvider,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        apiService: LLMAPIService,
        maxThinkingLength: Int = 100_000,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void,
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in }
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let url = URL(string: provider.baseURL) else {
            throw LLMServiceError.invalidBaseURL(provider.baseURL)
        }

        let prepared = provider.prepareMessagesForProvider(messages)
        var body = try provider.buildStreamingRequestBody(
            messages: prepared,
            model: config.model,
            tools: tools,
            systemPrompt: ""
        )
        provider.applyGenerationOptions(config: config, model: config.model, to: &body)

        let request = provider.buildRequest(url: url)
        let state = StreamingState(startTime: startTime, maxThinkingLength: maxThinkingLength)

        do {
            try await apiService.sendStreamingRequest(
                request: request,
                body: body,
                onRequestStart: onRequestStart
            ) { chunkData in
                do {
                    try Task.checkCancellation()

                    guard let parsed = try provider.parseStreamChunk(data: chunkData) else {
                        return true
                    }

                    let rawPayload = String(data: chunkData, encoding: .utf8)
                    let chunk = parsed.withRawStreamPayload(rawPayload)
                    await consume(chunk: chunk, state: state)
                    await onChunk(chunk)
                    return !chunk.isDone
                } catch {
                    return true
                }
            }
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error, provider: provider)
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

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            toolCalls: kitToolCalls?.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            providerId: config.providerId,
            modelName: config.model,
            latency: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            inputTokens: await state.inputTokens,
            outputTokens: await state.outputTokens,
            totalTokens: await state.totalTokens,
            timeToFirstToken: await state.timeToFirstToken,
            streamingDuration: await state.getStreamingDuration(),
            finishReason: await state.stopReason,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            thinkingContent: finalThinking
        )
    }

    private static func consume(chunk: StreamChunk, state: StreamingState) async {
        if let content = chunk.content, chunk.eventType == .textDelta {
            await state.recordFirstToken()
            await state.appendContent(content)
        }

        if let content = chunk.content, chunk.eventType == .thinkingDelta {
            await state.appendThinking(content)
        }

        if let toolCalls = chunk.toolCalls {
            await state.saveCurrentToolCall()
            if let firstToolCall = toolCalls.first {
                await state.startNewToolCall(
                    id: firstToolCall.id,
                    name: firstToolCall.name,
                    hasPartialJson: chunk.partialJson != nil,
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
    }

    private static func mapHTTPClientError(
        _ error: HTTPClientError,
        provider: any SuperLLMProvider
    ) -> LLMServiceError {
        switch error {
        case let .httpError(statusCode, message):
            let data = message.data(using: .utf8)
            if let parsed = provider.parseProviderHTTPError(data: data, statusCode: statusCode) {
                return LLMServiceError.requestFailed(
                    "[HTTP \(statusCode)] \(parsed.message)",
                    statusCode: statusCode
                )
            }
            return LLMServiceError.requestFailed("[HTTP \(statusCode)] \(message)", statusCode: statusCode)
        case let .requestFailed(underlying):
            return LLMServiceError.requestFailed(underlying.localizedDescription)
        default:
            return LLMServiceError.requestFailed(error.localizedDescription)
        }
    }
}
