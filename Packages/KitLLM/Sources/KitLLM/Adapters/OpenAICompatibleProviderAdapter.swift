import Foundation
import KitAgentTool

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
        messages: [LLMMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        try validateToolCallArguments(in: messages)
        var conversationMessages = transformMessages(messages)

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

    private func validateToolCallArguments(in messages: [LLMMessage]) throws {
        for message in messages {
            for toolCall in message.toolCalls ?? [] {
                try toolCall.validateArguments()
            }
        }
    }

    public func buildStreamingRequestBody(
        messages: [LLMMessage],
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
        messages: [LLMMessage],
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
        OpenAICompatibleGenerationOptionsApplier.apply(
            config: config,
            model: model,
            additionalReasoningEfforts: configuration.additionalReasoningEfforts,
            to: &body
        )
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

        // `VendorAPIError.httpStatus` 是传输层归一化后的标准错误形态
        // （见 PluginNetworkManager 的 `LLMNetworkProviderAdapter`）。
        // 必须在此显式取出状态码：它既不遵循 `LLMHTTPErrorProviding`，也不是
        // `NSURLErrorDomain` 错误，若漏判会退化为「不可重试」，
        // 导致 429 / 5xx / 529 等可恢复状态不触发任何重试。
        if case let .httpStatus(code, _, retryAfterSeconds) = error as? VendorAPIError {
            return ProviderRetryPolicy.decision(
                statusCode: code,
                // 错误自带的 `Retry-After` 优先：它来自实际响应头，比调用方
                // 传入的猜测值更可靠。
                retryAfter: retryAfterSeconds ?? retryAfter,
                attempt: attempt,
                maxAttempts: maxAttempts
            )
        }

        if let httpError = error as? LLMHTTPErrorProviding, let code = httpError.httpStatusCode {
            return ProviderRetryPolicy.decision(
                statusCode: code,
                retryAfter: retryAfter,
                attempt: attempt,
                maxAttempts: maxAttempts
            )
        }

        return ProviderRetryPolicy.decision(
            forNetworkError: error,
            attempt: attempt,
            maxAttempts: maxAttempts
        )
    }

    public func transformMessage(_ message: LLMMessage) -> [String: Any] {
        if let toolCallID = message.toolCallID {
            return [
                "role": MessageRole.tool.rawValue,
                "tool_call_id": toolCallID,
                "content": message.content,
            ]
        }

        // OpenAI-compatible endpoints expect vision input on user messages.
        // In particular, a tool result screenshot must be normalized by
        // transformMessages into a synthetic user message; never emit an
        // image content array for assistant history.
        let images = message.role == .user ? message.images : []
        var dict: [String: Any] = [
            "role": message.role.rawValue,
            "content": VisionMessageContentBuilder.openAIContent(
                text: message.content,
                images: images
            ),
        ]

        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            dict["tool_calls"] = toolCalls.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": "function",
                    "function": [
                        // 历史消息回传同样要转义，否则下一轮请求仍会被供应商 400 拒绝
                        "name": LLMToolNameSanitizer.sanitize(toolCall.name),
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

    /// OpenAI-compatible chat endpoints generally accept only text in a
    /// `tool` message. Keep the tool-result sequence protocol-valid, then add
    /// one synthetic user vision message after each contiguous tool-result
    /// batch so screenshots returned by tools are visible on the next model
    /// turn. Anthropic adapters support images directly inside tool_result and
    /// do not use this normalization path.
    private func transformMessages(_ messages: [LLMMessage]) -> [[String: Any]] {
        let normalizedMessages = normalizeToolResultOrder(messages)
        var output: [[String: Any]] = []
        var index = 0
        var expectedToolCallIDs = Set<String>()

        while index < normalizedMessages.count {
            let message = normalizedMessages[index]
            guard message.role == .tool else {
                output.append(transformMessage(message))
                expectedToolCallIDs = message.role == .assistant
                    ? Set(message.toolCalls?.map(\.id) ?? [])
                    : []
                index += 1
                continue
            }

            var resultImages: [MessageImage] = []
            var toolResultsByID: [String: LLMMessage] = [:]
            var toolResultOrder: [String] = []
            while index < normalizedMessages.count {
                var result = normalizedMessages[index]
                guard result.role == .tool else { break }
                index += 1

                guard let toolCallID = result.toolCallID,
                      expectedToolCallIDs.contains(toolCallID),
                      !Self.isPermissionPlaceholder(result.content) else {
                    continue
                }

                resultImages.append(contentsOf: result.images)
                result.images = []
                if toolResultsByID[toolCallID] == nil {
                    toolResultOrder.append(toolCallID)
                }
                // 旧会话可能已经包含同一 tool_call_id 的授权占位结果和
                // 最终结果；保留最后一个真实结果，避免生成非法连续 tool 消息。
                toolResultsByID[toolCallID] = result
            }

            for toolCallID in toolResultOrder {
                if let result = toolResultsByID[toolCallID] {
                    output.append(transformMessage(result))
                }
            }
            expectedToolCallIDs = []

            if !resultImages.isEmpty {
                output.append([
                    "role": MessageRole.user.rawValue,
                    "content": VisionMessageContentBuilder.openAIContent(
                        text: "Updated screenshot returned by the preceding tool result. Use it only as the current visual state of the requested interface.",
                        images: resultImages
                    ),
                ])
            }
        }

        return output
    }

    /// 修复交互工具恢复时的落库竞态：用户消息可能先于恢复后的 tool 结果写入，
    /// 但 OpenAI 兼容协议要求 tool 结果紧跟对应的 assistant.tool_calls。
    ///
    /// 如果历史中完全找不到结果，则移除这次孤立的 tool_calls，避免旧会话继续
    /// 阻塞后续请求；工具调用结果本身仍由本地消息/UI 历史保留。
    private func normalizeToolResultOrder(_ messages: [LLMMessage]) -> [LLMMessage] {
        var normalized = messages
        var index = 0

        while index < normalized.count {
            guard normalized[index].role == .assistant,
                  let toolCalls = normalized[index].toolCalls,
                  !toolCalls.isEmpty else {
                index += 1
                continue
            }

            let expectedToolCallIDs = Set(toolCalls.map(\.id))
            var scanIndex = index + 1
            var resultIndices: [Int] = []
            while scanIndex < normalized.count {
                if normalized[scanIndex].role == .assistant { break }
                if normalized[scanIndex].role == .tool,
                   let toolCallID = normalized[scanIndex].toolCallID,
                   expectedToolCallIDs.contains(toolCallID),
                   !Self.isPermissionPlaceholder(normalized[scanIndex].content) {
                    resultIndices.append(scanIndex)
                }
                scanIndex += 1
            }

            if !resultIndices.isEmpty {
                let results = resultIndices.map { normalized[$0] }
                for resultIndex in resultIndices.reversed() {
                    normalized.remove(at: resultIndex)
                }
                normalized.insert(contentsOf: results, at: index + 1)

                // 移除**没有配对结果**的 tool_call 声明。
                //
                // 一次 assistant 回合可以请求多个工具，部分完成就中断时
                // 会有调用没有结果（协议要求每个调用都有结果）。此前这里
                // 看到「至少有一个结果」就保留全部声明，未配对的调用会让
                // 上游直接拒绝请求。已完成的结果必须保留。
                let answeredIDs = Set(results.compactMap(\.toolCallID))
                let answered = toolCalls.filter { answeredIDs.contains($0.id) }
                if answered.count != toolCalls.count {
                    normalized[index].toolCalls = answered
                }

                index += results.count + 1
                continue
            }

            // 发送层遇到无结果的历史 tool call 时，不能继续生成供应商必拒的请求。
            // 只移除出站副本中的 tool_calls，不修改本地持久化消息。
            normalized[index].toolCalls = nil
            index += 1
        }

        return normalized
    }

    /// 授权流程产生的临时消息不是工具执行结果，不应发送给 LLM。
    /// 旧会话可能已经持久化了这类消息，因此发送层也要做兼容清理。
    ///
    /// - Note: 判据来自共享契约 `ToolSuspensionKind`（`KitAgentTool`）。
    ///   这里硬编码 `"permission"` 字面量的话，契约一旦改名，本函数会
    ///   静默返回 false——授权占位消息被原样发给 LLM，进而产生非法的
    ///   连续 tool 消息并触发上游 400。症状与根因相隔很远，极难归因。
    private static func isPermissionPlaceholder(_ content: String) -> Bool {
        ToolSuspensionKind.isPermissionRequest(content)
    }

    public func formatTool(_ tool: any LLMToolSchemaProviding) -> [String: Any] {
        [
            "type": "function",
            "function": [
                // OpenAI 协议同样要求函数名只含字母/数字/下划线/短横线，
                // 带点号的 MCP 工具名（如 app-store-connect.list-apps）须转义
                "name": LLMToolNameSanitizer.sanitize(tool.name),
                "description": tool.toolDescription,
                "parameters": tool.inputSchema,
            ],
        ]
    }

    public func parseResponse(
        data: Data,
        reverseMap: [String: String]? = nil
    ) throws -> (
        content: String,
        toolCalls: [ToolCall]?,
        reasoningContent: String?,
        images: [MessageImage]?,
        responseID: String?,
        stopReason: String?
    ) {
        if let errorResponse = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data) {
            throw OpenAICompatibleProviderError.apiError(message: errorResponse.error.message)
        }

        let response = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)

        guard let choiceMessage = response.choices.first?.message else {
            throw OpenAICompatibleProviderError.noChoices
        }

        // 工具名经 `formatTool`/`transformMessage` sanitize（点号→下划线），这里须按
        // reverseMap 还原成 注册 id，否则工具调度按原始 id 查找时会找不到工具。
        // 与流式路径 流式路径的 toolNameReverseMap 语义一致；
        // reverseMap 为空/未提供时原样透传（无工具场景）。
        let toolCalls = choiceMessage.toolCalls?.map { toolCall in
            ToolCall(
                id: toolCall.id,
                name: reverseMap?[toolCall.function.name] ?? toolCall.function.name,
                arguments: toolCall.function.arguments
            )
        }

        // 正文优先；正文缺失时回退到拒答文本。
        //
        // OpenAI 在模型拒绝作答时返回 `content: null` + `message.refusal`。
        // 只取 `content` 会把一次合法拒答变成空串，随后在 AgentLoop 层被
        // 重新归类为「模型返回空响应」，用户看到的是通用失败提示而不是
        // 模型给出的拒绝说明。
        let content = choiceMessage.content ?? choiceMessage.refusal ?? ""

        // 生成的图片（图像生成模型的产物）。
        //
        // 没有这个字段时，一次合法的「只生成图片」的响应会被当成空响应：
        // 内容为空、没有工具调用、也没有思考——生成的图片直接丢失。
        let images = choiceMessage.images?.compactMap { $0.decodedImage() }

        // 响应元数据：顶层 `id` 与 `choices[].finish_reason`。
        //
        // 两者都是标准字段——关联 ID 让下游能把请求与供应商日志对上，
        // finish_reason 让截断的回答（`length`）能说明「为什么没说完」。
        return (
            content,
            toolCalls,
            choiceMessage.reasoningContent,
            images,
            response.id,
            response.choices.first?.finishReason
        )
    }

    /// 解析单个 SSE 事件，返回该事件产出的**有序事件列表**。
    ///
    /// 为什么是列表而不是单个 chunk：OpenAI 兼容协议允许同一个 `delta` 里
    /// 同时携带 `reasoning_content` 与 `content`。interleaved thinking 模型
    /// （MiniMax M3 / M3.1 等思考默认开启且无法关闭的模型）会高频产生这种
    /// 形态，而 `StreamChunk` 只有一个 `content` 字段、靠 `eventType` 决定
    /// 去向，因此无法用单个 chunk 同时表达「思考与正文都要保留」。
    ///
    /// 早期实现遇到并存形态时只返回思考、静默丢弃正文，累积器的
    /// `content` 恒为空，最终在 AgentLoop 层被判为「模型返回空响应」
    /// 而走失败链路（思考内容反而正常显示）。这里改为分别产出
    /// `.thinkingDelta` 与 `.textDelta`，两种增量都不再丢失。
    ///
    /// - Returns: 按协议顺序排列的 chunk 列表；该事件不产出任何增量时返回空数组。
    public func parseStreamChunks(data: Data) throws -> [StreamChunk] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let eventData = extractSSEData(from: text)

        guard let dataString = eventData, !dataString.isEmpty else {
            return []
        }

        if dataString == "[DONE]" {
            return [StreamChunk(isDone: true)]
        }

        guard let jsonData = dataString.data(using: .utf8) else {
            return []
        }

        let json: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return []
            }
            json = object
        } catch {
            return []
        }

        if let error = json["error"] as? [String: Any],
           let errorMessage = error["message"] as? String {
            return [StreamChunk(error: errorMessage)]
        }

        var chunks: [StreamChunk] = []

        // 顶层响应 ID（`chatcmpl-...`）：供应商的关联标识，下游要靠它把
        // 一次请求与它的日志对上。
        let responseID = json["id"] as? String

        // MARK: - Parse content/reasoning/toolCalls first
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any] {
            let usage = json["usage"] as? [String: Any]
            let tokenCounts = Self.tokenCounts(from: usage)
            let inputTokens = tokenCounts.input
            let outputTokens = tokenCounts.output
            let cacheWriteInputTokens = Self.cacheWriteInputTokens(from: usage)
            let cachedInputTokens = Self.cacheReadInputTokens(from: usage)
                ?? (cacheWriteInputTokens == nil ? nil : 0)
            let stopReason = delta["stop_reason"] as? String
                ?? firstChoice["finish_reason"] as? String

            // 思考增量与正文增量各自独立产出：二者可以同时存在，
            // 都不因对方的存在而被丢弃。
            //
            // `reasoning_content` 与 `reasoning` 是同一个语义的两个别名：
            // OpenRouter 用 `reasoning`，其它供应商多用 `reasoning_content`。
            if let reasoningContent = (delta["reasoning_content"] as? String ?? delta["reasoning"] as? String),
               !reasoningContent.isEmpty {
                chunks.append(StreamChunk(
                    content: reasoningContent,
                    eventType: .thinkingDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens,
                    stopReason: stopReason
                ))
            }

            if let content = delta["content"] as? String, !content.isEmpty {
                chunks.append(StreamChunk(
                    content: content,
                    eventType: .textDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens,
                    stopReason: stopReason
                ))
            }

            // 生成的图片增量（图像生成模型的 `delta.images`）。
            //
            // 与思考 / 正文增量一样独立产出：三者可以同时存在，互不覆盖。
            // 没有这个分支时，一次合法的「只生成图片」的流式响应不会有任何
            // 增量产出，流以空内容正常结束，随后被当成空响应。
            if let images = Self.parseImageDelta(delta["images"]), !images.isEmpty {
                chunks.append(StreamChunk(
                    eventType: .textDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens,
                    stopReason: stopReason,
                    images: images
                ))
            }

            // 拒答增量（OpenAI 的 `delta.refusal`）。
            //
            // 拒答时 `delta.content` 为空，拒答说明只出现在这个字段里。
            // 不读它会让一次合法拒答在流式下累积为空内容，随后被
            // AgentLoop 重新归类为「模型返回空响应」——模型明确拒绝了，
            // 用户看到的却是通用失败提示。
            //
            // 与 `content` / `reasoning_content` 一样独立产出：三者可以
            // 同时存在，互不覆盖。
            if let refusal = delta["refusal"] as? String, !refusal.isEmpty {
                chunks.append(StreamChunk(
                    content: refusal,
                    eventType: .textDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens,
                    stopReason: stopReason
                ))
            }

            // 工具调用：与思考/正文**各自独立**产出，不再受 `chunks.isEmpty` 约束。
            //
            // 曾经的 `if chunks.isEmpty` 守卫会把「同一 delta 内同时带
            // reasoning_content + tool_calls」的形态整包丢弃。interleaved
            // thinking 模型（MiniMax M3 / M3.1 等思考默认开启且无法关闭）会
            // 在收敛阶段高频产生这种形态，于是工具调用被吞、累积器 content 恒
            // 为空，最终在 AgentLoop 层被判为「模型返回空响应」而走失败链路
            // （思考内容却正常显示，正是该 bug 的现场特征）。
            //
            // 三者并存时协议上并非歧义：字段键名互相独立，累加器也分别写入
            // reasoningContent / content / toolCalls，追加不会互相覆盖。
            if let toolCalls = delta["tool_calls"] as? [[String: Any]],
               !toolCalls.isEmpty {
                chunks.append(contentsOf: parseToolCallDelta(
                    toolCalls,
                    stopReason: stopReason,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens
                ))
            }

            // 纯 stop_reason 结束信号
            // DeepSeek 将最终 usage 放在带 choices/finish_reason 的最后一个
            // chunk 中，而不是发送独立的 usage-only chunk。不能在这里丢弃
            // token usage，否则速度和缓存命中率都无法落库。
            if chunks.isEmpty, let stopReason {
                chunks.append(StreamChunk(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: inputTokens,
                    stopReason: stopReason
                ))
            }
        }

        // MARK: - Usage-only chunk (no content delta)
        // 只有当没有 content/reasoning/toolCalls 时，才单独返回 usage
        // 某些供应商（如 StepFun）每个 chunk 都带 usage，但不能因此跳过内容
        if chunks.isEmpty {
            if let usage = json["usage"] as? [String: Any] {
                let tokenCounts = Self.tokenCounts(from: usage)
                chunks.append(StreamChunk(
                    inputTokens: tokenCounts.input,
                    outputTokens: tokenCounts.output,
                    cachedInputTokens: Self.cacheReadInputTokens(from: usage)
                        ?? (Self.cacheWriteInputTokens(from: usage) == nil ? nil : 0),
                    cacheWriteInputTokens: Self.cacheWriteInputTokens(from: usage),
                    cacheTotalInputTokens: tokenCounts.input
                ))
            } else if configuration.returnsEmptyChunkWhenNoDelta {
                chunks.append(StreamChunk(content: "", eventType: .textDelta))
            }
        }

        // 统一补上响应 ID：chunk 构造点分散在各分支里，逐个加参数容易漏。
        guard let responseID else { return chunks }
        return chunks.map { $0.withResponseID(responseID) }
    }

    /// 解析流式事件里的图片增量。
    ///
    /// 与非流式的 `ImageData.decodedImage()` 用同一套解码规则：只接受
    /// `data:` URL（base64 内联），外链 URL 无法在不额外下载的前提下变成
    /// 图片数据。
    static func parseImageDelta(_ value: Any?) -> [MessageImage]? {
        guard let entries = value as? [[String: Any]], !entries.isEmpty else { return nil }
        var images: [MessageImage] = []
        for entry in entries {
            guard let imageURL = entry["image_url"] as? [String: Any],
                  let url = imageURL["url"] as? String,
                  url.hasPrefix("data:") else { continue }
            guard let commaIndex = url.firstIndex(of: ",") else { continue }
            let metadata = String(url[url.startIndex..<commaIndex])
            let payload = String(url[url.index(after: commaIndex)...])
            guard metadata.contains("base64"), let data = Data(base64Encoded: payload) else { continue }
            let mimeType = String(metadata.dropFirst("data:".count).prefix(while: { $0 != ";" }))
            images.append(MessageImage(data: data, mimeType: mimeType.isEmpty ? "image/png" : mimeType))
        }
        return images.isEmpty ? nil : images
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

    /// 读取 usage 里的缓存命中 token 数。
    ///
    /// 公开给其它 provider 插件复用：不同网关的 usage 字段名各异，
    /// 但「缓存命中」这一个语义必须有一致口径，否则缓存命中率统计会
    /// 把部分协议（Responses / Anthropic 兼容等）的轮次悄悄排除在外。
    public static func cacheReadInputTokens(from usage: [String: Any]?) -> Int? {
        usage?["cached_tokens"] as? Int
            ?? (usage?["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            ?? (usage?["input_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            ?? usage?["cache_read_input_tokens"] as? Int
            // DeepSeek OpenAI API
            ?? usage?["prompt_cache_hit_tokens"] as? Int
    }

    /// 读取 usage 里的缓存写入 token 数。口径同 ``cacheReadInputTokens(from:)``。
    public static func cacheWriteInputTokens(from usage: [String: Any]?) -> Int? {
        usage?["cache_write_tokens"] as? Int
            ?? usage?["cache_creation_input_tokens"] as? Int
            ?? (usage?["prompt_tokens_details"] as? [String: Any])?["cache_write_tokens"] as? Int
            ?? (usage?["input_tokens_details"] as? [String: Any])?["cache_write_tokens"] as? Int
    }

    /// OpenAI-compatible gateways do not all use the same usage spelling.
    /// Keep the aliases here so the shared streaming accumulator can preserve
    /// usage for every provider without provider-specific parsers.
    private static func tokenCounts(from usage: [String: Any]?) -> (input: Int?, output: Int?) {
        guard let usage else { return (nil, nil) }
        return (
            usage["prompt_tokens"] as? Int
                ?? usage["input_tokens"] as? Int
                ?? usage["prompt_token_count"] as? Int
                ?? usage["input_token_count"] as? Int,
            usage["completion_tokens"] as? Int
                ?? usage["output_tokens"] as? Int
                ?? usage["candidates_token_count"] as? Int
                ?? usage["output_token_count"] as? Int
        )
    }

    private func parseToolCallDelta(
        _ toolCalls: [[String: Any]],
        stopReason: String?,
        inputTokens: Int?,
        outputTokens: Int?,
        cachedInputTokens: Int?,
        cacheWriteInputTokens: Int?,
        cacheTotalInputTokens: Int?
    ) -> [StreamChunk] {
        // OpenAI 流式 `tool_calls[].index` 标识并行调用各自的槽位。同一 delta
        // 可能携带多个 index，必须按 index 分组、每个 index 产出一个独立 chunk，
        // 累积器才能把 arguments 精确累积到对应调用。此前整个数组共用一个
        // toolCallIndex（循环结束只保留最后一个），所有调用被写进同一槽：
        // ID/name 取第一个、arguments 拼接成非法 JSON、其余调用丢失（#162）。
        //
        // 不带 index 的网关沿用旧行为：归入 nil-index 组，由累积器的 nextIndex
        // 逐调用、跨 delta 递增分配槽位；不能在这里给它们硬塞 index，否则每个
        // delta 的首个调用都会塌缩到 index 0 而被错误合并。
        var explicitCalls: [Int: [ToolCall]] = [:]
        var explicitPartial: [Int: String] = [:]
        var implicitCalls: [ToolCall] = []
        var implicitPartial: String?

        for toolCall in toolCalls {
            guard let function = toolCall["function"] as? [String: Any] else {
                continue
            }

            let id = resolveToolCallID(toolCall: toolCall, function: function)
            let name = function["name"] as? String
            let arguments = function["arguments"] as? String

            // 身份字段可能分散在不同 delta：
            //
            // ```
            // delta 1: {"index":0,"id":"call_1","function":{}}
            // delta 2: {"index":0,"function":{"name":"lookup","arguments":"{}"}}
            // ```
            //
            // 只要有任何身份字段就产出调用，缺失的留空由累积器合并
            // （`upsertToolCall` 逐字段取非空值）。
            let call: ToolCall? = (id != nil || name != nil || arguments != nil)
                ? ToolCall(
                    id: id ?? "",
                    name: name ?? "",
                    // 占位参数用空串而不是 "{}"：累积器把 "{}" 当作
                    // 「尚未收到真实参数」的标记，真实分片会被正确拼接。
                    arguments: arguments ?? ""
                )
                : nil

            if let index = toolCall["index"] as? Int {
                if let call {
                    explicitCalls[index, default: []].append(call)
                }
                if let arguments {
                    explicitPartial[index] = arguments
                }
            } else {
                if let call {
                    implicitCalls.append(call)
                }
                if let arguments {
                    implicitPartial = arguments
                }
            }
        }

        func makeChunk(index: Int?, calls: [ToolCall], partial: String?) -> StreamChunk? {
            if !calls.isEmpty {
                return StreamChunk(
                    toolCalls: calls,
                    partialJson: partial,
                    toolCallIndex: index,
                    eventType: .contentBlockStart,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: cacheTotalInputTokens,
                    stopReason: stopReason
                )
            }
            if let partial {
                return StreamChunk(
                    partialJson: partial,
                    toolCallIndex: index,
                    eventType: .inputJsonDelta,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedInputTokens: cachedInputTokens,
                    cacheWriteInputTokens: cacheWriteInputTokens,
                    cacheTotalInputTokens: cacheTotalInputTokens,
                    stopReason: stopReason
                )
            }
            return nil
        }

        var chunks: [StreamChunk] = []
        // 按 index 升序产出，保证最终调用顺序与协议槽位一致。
        let explicitIndices = Set(explicitCalls.keys).union(explicitPartial.keys).sorted()
        for index in explicitIndices {
            if let chunk = makeChunk(
                index: index,
                calls: explicitCalls[index] ?? [],
                partial: explicitPartial[index]
            ) {
                chunks.append(chunk)
            }
        }
        if let chunk = makeChunk(index: nil, calls: implicitCalls, partial: implicitPartial) {
            chunks.append(chunk)
        }
        return chunks
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
