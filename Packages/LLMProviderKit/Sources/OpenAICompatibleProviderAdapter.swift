import Foundation
import HttpKit
import LLMKit

public struct OpenAICompatibleProviderAdapter: Sendable {
    public let configuration: OpenAICompatibleProviderConfiguration

    public init(configuration: OpenAICompatibleProviderConfiguration) {
        self.configuration = configuration
    }

    public func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        for (field, value) in configuration.additionalHeaders {
            request.addValue(value, forHTTPHeaderField: field)
        }

        return request
    }

    public func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        var conversationMessages = messages.map(transformMessage)

        if !systemPrompt.isEmpty,
           !conversationMessages.contains(where: { ($0["role"] as? String) == MessageRole.system.rawValue }) {
            conversationMessages.insert(
                [
                    "role": MessageRole.system.rawValue,
                    "content": systemPrompt,
                ],
                at: 0
            )
        }

        var body: [String: Any] = [
            "model": model,
            "messages": conversationMessages,
            "stream": false,
        ]

        if let tools, !tools.isEmpty {
            body["tools"] = tools.map(formatTool)
        }

        return body
    }

    public func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        var body = try buildRequestBody(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
        body["stream"] = true

        if configuration.includeUsageInStreamOptions {
            body["stream_options"] = ["include_usage": true]
        }

        return body
    }

    public func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        systemPrompt: String,
        config: LLMConfig
    ) throws -> [String: Any] {
        var body = try buildStreamingRequestBody(
            messages: LLMMessagePreparer.prepare(messages),
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: model, to: &body)
        return body
    }

    public static func retryDecision(
        for error: Error,
        statusCode: Int?,
        attempt: Int,
        maxAttempts: Int,
        retryAfter: TimeInterval? = nil
    ) -> ProviderRetryDecision {
        if let llmError = error as? LLMServiceError {
            switch llmError {
            case .cancelled:
                return .doNotRetry
            case let .requestFailed(_, code):
                return ProviderRetryPolicy.decision(
                    statusCode: code ?? statusCode,
                    retryAfter: retryAfter,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            default:
                return .doNotRetry
            }
        }

        if let apiError = error as? HTTPClientError {
            switch apiError {
            case let .httpError(code, _):
                return ProviderRetryPolicy.decision(
                    statusCode: code,
                    retryAfter: retryAfter,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            case let .requestFailed(underlying):
                return ProviderRetryPolicy.decision(
                    forNetworkError: underlying,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            default:
                break
            }
        }

        return ProviderRetryPolicy.decision(
            forNetworkError: error,
            attempt: attempt,
            maxAttempts: maxAttempts
        )
    }

    public func transformMessage(_ message: ChatMessage) -> [String: Any] {
        if let toolCallID = message.toolCallID {
            return [
                "role": MessageRole.tool.rawValue,
                "tool_call_id": toolCallID,
                "content": message.content,
            ]
        }

        var dict: [String: Any] = [
            "role": message.role.rawValue,
            "content": VisionMessageContentBuilder.openAIContent(
                text: message.content,
                images: message.images
            ),
        ]

        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            dict["tool_calls"] = toolCalls.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": "function",
                    "function": [
                        "name": toolCall.name,
                        "arguments": toolCall.arguments,
                    ],
                ]
            }
        }

        if configuration.includesReasoningContentInMessages,
           message.role == .assistant,
           let reasoningContent = message.reasoningContent,
           !reasoningContent.isEmpty {
            dict["reasoning_content"] = reasoningContent
        }

        return dict
    }

    public func formatTool(_ tool: any LLMToolSchemaProviding) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": tool.name,
                "description": tool.toolDescription,
                "parameters": tool.inputSchema,
            ],
        ]
    }

    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?, reasoningContent: String?) {
        if let errorResponse = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data) {
            throw OpenAICompatibleProviderError.apiError(message: errorResponse.error.message)
        }

        let response = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)

        guard let choiceMessage = response.choices.first?.message else {
            throw OpenAICompatibleProviderError.noChoices
        }

        let toolCalls = choiceMessage.toolCalls?.map { toolCall in
            ToolCall(
                id: toolCall.id,
                name: toolCall.function.name,
                arguments: toolCall.function.arguments
            )
        }

        return (choiceMessage.content ?? "", toolCalls, choiceMessage.reasoningContent)
    }

    public func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let eventData = extractSSEData(from: text)

        guard let dataString = eventData, !dataString.isEmpty else {
            return nil
        }

        if dataString == "[DONE]" {
            return StreamChunk(isDone: true)
        }

        guard let jsonData = dataString.data(using: .utf8) else {
            return nil
        }

        let json: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }
            json = object
        } catch {
            return nil
        }

        if let error = json["error"] as? [String: Any],
           let errorMessage = error["message"] as? String {
            return StreamChunk(error: errorMessage)
        }

        // MARK: - Parse content/reasoning/toolCalls first
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any] {
            let usage = json["usage"] as? [String: Any]
            let inputTokens = usage?["prompt_tokens"] as? Int
            let outputTokens = usage?["completion_tokens"] as? Int
            let stopReason = delta["stop_reason"] as? String

            // 优先解析 reasoning_content（思考过程）
            // 注意：即使同时包含 content，也要先处理 reasoning_content
            if let reasoningContent = delta["reasoning_content"] as? String,
               !reasoningContent.isEmpty {
                return StreamChunk(
                    content: reasoningContent,
                    eventType: .thinkingDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    stopReason: stopReason
                )
            }

            // 解析正文内容（跳过空字符串）
            if let content = delta["content"] as? String, !content.isEmpty {
                return StreamChunk(
                    content: content,
                    eventType: .textDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    stopReason: stopReason
                )
            }

            // 解析工具调用
            if let toolCalls = delta["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                return parseToolCallDelta(toolCalls, stopReason: stopReason)
            }

            // 纯 stop_reason 结束信号
            if let stopReason {
                return StreamChunk(stopReason: stopReason, eventTitle: "")
            }
        }

        // MARK: - Usage-only chunk (no content delta)
        // 只有当没有 content/reasoning/toolCalls 时，才单独返回 usage
        // 某些供应商（如 StepFun）每个 chunk 都带 usage，但不能因此跳过内容
        if let usage = json["usage"] as? [String: Any] {
            return StreamChunk(
                inputTokens: usage["prompt_tokens"] as? Int,
                outputTokens: usage["completion_tokens"] as? Int
            )
        }

        if configuration.returnsEmptyChunkWhenNoDelta {
            return StreamChunk(content: "", eventType: .textDelta)
        }

        return nil
    }

    private func extractSSEData(from text: String) -> String? {
        let dataLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.hasPrefix("data: ") {
                    return String(trimmed.dropFirst(6))
                }

                if trimmed.hasPrefix("data:") {
                    return String(trimmed.dropFirst(5))
                }

                if trimmed == "data:" {
                    return ""
                }

                return nil
            }

        guard !dataLines.isEmpty else {
            return nil
        }

        return dataLines.joined(separator: "\n")
    }

    private func parseToolCallDelta(_ toolCalls: [[String: Any]], stopReason: String?) -> StreamChunk? {
        var parsedToolCalls: [ToolCall] = []
        var partialJson: String?

        for toolCall in toolCalls {
            guard let function = toolCall["function"] as? [String: Any] else {
                continue
            }

            let id = resolveToolCallID(toolCall: toolCall, function: function)
            let name = function["name"] as? String
            let arguments = function["arguments"] as? String

            if let id, let name {
                parsedToolCalls.append(
                    ToolCall(
                        id: id,
                        name: name,
                        arguments: arguments ?? "{}"
                    )
                )
            }

            if let arguments {
                partialJson = arguments
            }
        }

        if !parsedToolCalls.isEmpty {
            return StreamChunk(
                toolCalls: parsedToolCalls,
                partialJson: partialJson,
                eventType: .contentBlockStart,
                stopReason: stopReason
            )
        }

        if let partialJson {
            return StreamChunk(
                partialJson: partialJson,
                eventType: .inputJsonDelta,
                stopReason: stopReason
            )
        }

        return nil
    }

    private func resolveToolCallID(toolCall: [String: Any], function: [String: Any]) -> String? {
        if let id = toolCall["id"] as? String {
            return id
        }

        if configuration.acceptsFunctionScopedToolCallID {
            return function["id"] as? String
        }

        return nil
    }
}
