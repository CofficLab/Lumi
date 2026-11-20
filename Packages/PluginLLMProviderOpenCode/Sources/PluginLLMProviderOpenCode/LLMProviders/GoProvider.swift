import Foundation
import KitLLM
import os
import ProviderLLMManager
import LumiLoggingKit
/// OpenCode Go 供应商（Go 系列模型网关）。
///
/// 同一网关下按模型走三种协议（Responses / OpenAI / Anthropic），
/// 端点路径不同（`/responses`、`/chat/completions`、`/messages`），因此
/// 覆盖 `complete(_:)` 和 `streamComplete` 按模型路由，不复用基类的单一协议路径。
@MainActor
public final class GoProvider: VendorLLMProvider, SuperLog {
    public nonisolated static let emoji = "🚀"
    nonisolated static let verbose = false

    /// 包装基类 `resolveAPIKey()`，在抛出前记录 error 日志。
    private func resolvedAPIKey() throws -> String {
        do {
            return try resolveAPIKey()
        } catch {
            Self.logger.error("\(Self.t)resolveAPIKey failed\(self.r(error.localizedDescription))")
            throw error
        }
    }

    private enum Kind {
        case responses
        case openAI
        case anthropic
    }

    private static let base = "https://opencode.ai/zen/go/v1"

    private static let kinds: [String: Kind] = [
        // Responses API
        "grok-4.5": .responses,
        "gpt-5.6-luna": .responses,
        // OpenAI-compatible
        "glm-5.3": .openAI,
        "glm-5.2": .openAI,
        "glm-5.1": .openAI,
        "kimi-k3": .openAI,
        "kimi-k2.7-code": .openAI,
        "kimi-k2.6": .openAI,
        "mimo-v2.5": .openAI,
        "mimo-v2.5-pro": .openAI,
        "deepseek-v4-pro": .openAI,
        "deepseek-v4-flash": .openAI,
        "muse-spark-1.2-contributor": .openAI,
        "hy3": .openAI,
        "ox-alpha-free": .openAI,
        // Anthropic-compatible
        "minimax-m3": .anthropic,
        "minimax-m2.7": .anthropic,
        "minimax-m2.5": .anthropic,
        "qwen3.8-max": .anthropic,
        "qwen3.7-max": .anthropic,
        "qwen3.7-plus": .anthropic,
        "qwen3.6-plus": .anthropic,
    ]

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "opencode-go",
                displayName: "OpenCode Go",
                description: "低成本的开源编程模型订阅服务",
                defaultModel: "deepseek-v4-flash",
                models: [
                    LLMModelInfo(id: "grok-4.5", displayName: "Grok 4.5", contextWindowSize: 500000),
                    LLMModelInfo(id: "gpt-5.6-luna", displayName: "GPT 5.6 Luna", contextWindowSize: 1050000),
                    LLMModelInfo(id: "glm-5.3", displayName: "GLM-5.3", contextWindowSize: 1000000),
                    LLMModelInfo(id: "glm-5.2", displayName: "GLM-5.2", contextWindowSize: 1000000),
                    LLMModelInfo(id: "glm-5.1", displayName: "GLM-5.1", contextWindowSize: 202752),
                    LLMModelInfo(id: "kimi-k3", displayName: "Kimi K3", contextWindowSize: 1048576),
                    LLMModelInfo(id: "kimi-k2.7-code", displayName: "Kimi K2.7 Code", contextWindowSize: 262144),
                    LLMModelInfo(id: "kimi-k2.6", displayName: "Kimi K2.6", contextWindowSize: 262144),
                    LLMModelInfo(id: "mimo-v2.5", displayName: "MiMo-V2.5", contextWindowSize: 1000000),
                    LLMModelInfo(id: "mimo-v2.5-pro", displayName: "MiMo-V2.5-Pro", contextWindowSize: 1048576),
                    LLMModelInfo(id: "deepseek-v4-pro", displayName: "DeepSeek V4 Pro", contextWindowSize: 1000000),
                    LLMModelInfo(id: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash", contextWindowSize: 1000000),
                    LLMModelInfo(id: "muse-spark-1.2-contributor", displayName: "Muse Spark 1.2", contextWindowSize: 1000000),
                    LLMModelInfo(id: "hy3", displayName: "Hy3", contextWindowSize: 256000),
                    LLMModelInfo(id: "ox-alpha-free", displayName: "Ox Alpha Free", contextWindowSize: 256000),
                    LLMModelInfo(id: "minimax-m3", displayName: "MiniMax M3", contextWindowSize: 1000000),
                    LLMModelInfo(id: "minimax-m2.7", displayName: "MiniMax M2.7", contextWindowSize: 204800),
                    LLMModelInfo(id: "minimax-m2.5", displayName: "MiniMax M2.5", contextWindowSize: 204800),
                    LLMModelInfo(id: "qwen3.8-max", displayName: "Qwen3.8 Max", contextWindowSize: 1000000),
                    LLMModelInfo(id: "qwen3.7-max", displayName: "Qwen3.7 Max", contextWindowSize: 1000000),
                    LLMModelInfo(id: "qwen3.7-plus", displayName: "Qwen3.7 Plus", contextWindowSize: 1000000),
                    LLMModelInfo(id: "qwen3.6-plus", displayName: "Qwen3.6 Plus", contextWindowSize: 1000000),
                ],
                websiteURL: URL(string: "https://opencode.ai/docs/zh-cn/go/")!,
                providerType: .cloudService,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_OpenCodeGo"
            ),
            apiService: apiService
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)GoProvider initialized with \(Self.kinds.count) models")
        }
    }

    // MARK: - 按模型路由协议

    override public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        guard let kind = Self.kinds[model] else {
            Self.logger.error("\(Self.t)Unknown model: \(model, privacy: .public)")
            throw VendorAPIError.requestFailed("OpenCode Go 未知模型：\(model)")
        }
        if Self.verbose {
            Self.logger.debug("\(Self.t)complete model=\(model, privacy: .public) kind=\(String(describing: kind))")
        }
        let apiKey = try resolvedAPIKey()
        switch kind {
        case .responses:
            return try await sendResponses(request, model: model, apiKey: apiKey)
        case .openAI:
            return try await sendChat(request, model: model, apiKey: apiKey, anthropic: false)
        case .anthropic:
            return try await sendChat(request, model: model, apiKey: apiKey, anthropic: true)
        }
    }

    override public func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        guard let kind = Self.kinds[model] else {
            Self.logger.error("\(Self.t)Unknown model: \(model, privacy: .public)")
            throw VendorAPIError.requestFailed("OpenCode Go 未知模型：\(model)")
        }
        if Self.verbose {
            Self.logger.debug("\(Self.t)streamComplete model=\(model, privacy: .public) kind=\(String(describing: kind))")
        }
        let apiKey = try resolvedAPIKey()
        switch kind {
        case .responses:
            return try await streamResponses(request, model: model, apiKey: apiKey, onChunk: onChunk)
        case .openAI:
            return try await streamChat(request, model: model, apiKey: apiKey, anthropic: false, onChunk: onChunk)
        case .anthropic:
            return try await streamChat(request, model: model, apiKey: apiKey, anthropic: true, onChunk: onChunk)
        }
    }

    // MARK: - OpenAI / Anthropic (non-streaming)

    private func sendChat(
        _ request: LLMRequest,
        model: String,
        apiKey: String,
        anthropic: Bool
    ) async throws -> LLMResponse {
        let url = try endpointURL(anthropic ? "\(Self.base)/messages" : "\(Self.base)/chat/completions")
        if Self.verbose {
            Self.logger.debug("\(Self.t)sendChat model=\(model, privacy: .public) anthropic=\(anthropic) url=\(url.path, privacy: .public)")
        }
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        if anthropic {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
            let body = try adapter.buildRequestBody(
                messages: request.messages,
                model: model,
                tools: tools,
                systemPrompt: ""
            )
            let data = try await apiService.sendChatRequest(
                request: adapter.buildRequest(url: url, apiKey: apiKey),
                body: body
            )
            let parsed = try adapter.parseResponse(data: data, reverseMap: reverseMap)
            let tokenCounts = Self.tokenCounts(from: data, anthropic: true)
            if Self.verbose {
                Self.logger.debug("\(Self.t)sendChat anthropic response received, content length=\(parsed.content.count)")
            }
            return LLMResponse(
                content: parsed.content,
                model: model,
                // 必须带上解析出的工具调用：`LLMResponse.toolCalls` 默认是
                // `nil`，漏掉它会把一次合法的「只调用工具」的响应变成空文本
                // 响应，调用方无法执行被请求的工具。
                toolCalls: parsed.toolCalls?.map {
                    LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
                },
                inputTokenCount: tokenCounts.input,
                outputTokenCount: tokenCounts.output
            )
        }

        let adapter = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
        let body = try adapter.buildRequestBody(
            messages: request.messages,
            model: model,
            tools: tools,
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: url, apiKey: apiKey),
            body: body
        )
        let parsed = try adapter.parseResponse(data: data, reverseMap: reverseMap)
        let tokenCounts = Self.tokenCounts(from: data, anthropic: false)
        if Self.verbose {
            Self.logger.debug("\(Self.t)sendChat openAI response received, content length=\(parsed.content.count)")
        }
        return LLMResponse(
            content: parsed.content,
            model: model,
            // 必须带上解析出的工具调用：`LLMResponse.toolCalls` 默认是
            // `nil`，漏掉它会把一次合法的「只调用工具」的响应变成空文本
            // 响应，调用方无法执行被请求的工具。
            toolCalls: parsed.toolCalls?.map {
                LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            inputTokenCount: tokenCounts.input,
            outputTokenCount: tokenCounts.output
        )
    }

    // MARK: - OpenAI / Anthropic (streaming)

    private func streamChat(
        _ request: LLMRequest,
        model: String,
        apiKey: String,
        anthropic: Bool,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        if Self.verbose {
            Self.logger.debug("\(Self.t)streamChat model=\(model, privacy: .public) anthropic=\(anthropic)")
        }
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        if anthropic {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
            nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
                messages: request.messages,
                model: model,
                tools: tools,
                systemPrompt: "",
                // 必须带上 `request.reasoningEffort`：重建 LLMConfig 时漏掉它，
                // 生成参数 applier 就不会下发 thinking 配置，用户选定的推理
                // 档位被静默丢弃，实际拿到的是供应商的默认推理行为。
                config: LLMConfig(
                    model: model,
                    providerId: providerInfo.id,
                    reasoningEffort: request.reasoningEffort
                )
            )
            let accumulator = GoStreamingAccumulator()
            try await apiService.sendStreamingChatRequest(
                request: adapter.buildRequest(url: try endpointURL("\(Self.base)/messages"), apiKey: apiKey),
                body: body
            ) { data in
                do {
                    var chunk = try adapter.parseStreamChunk(data: data)
                    if let reverseMap, !reverseMap.isEmpty, let toolCalls = chunk?.toolCalls {
                        chunk = chunk?.withToolCalls(
                            toolCalls.map { ToolCall(id: $0.id, name: reverseMap[$0.name] ?? $0.name, arguments: $0.arguments) }
                        )
                    }
                    guard let chunk else { return true }
                    return await accumulator.consume(chunk, onChunk: onChunk)
                } catch {
                    accumulator.fail(error)
                    return false
                }
            }
            return try accumulator.finish(model: model)
        }

        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(baseURL: Self.base, includeUsageInStreamOptions: true)
        )
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: request.messages,
            model: model,
            tools: tools,
            systemPrompt: "",
            // 必须带上 `request.reasoningEffort`：重建 LLMConfig 时漏掉它，
            // 生成参数 applier 就不会下发 reasoning_effort，用户选定的推理
            // 档位被静默丢弃，实际拿到的是供应商的默认推理行为。
            config: LLMConfig(
                model: model,
                providerId: providerInfo.id,
                reasoningEffort: request.reasoningEffort
            )
        )
        let accumulator = GoStreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL("\(Self.base)/chat/completions"), apiKey: apiKey),
            body: body
        ) { data in
            do {
                var parsed = try adapter.parseStreamChunks(data: data)
                if let reverseMap, !reverseMap.isEmpty {
                    parsed = parsed.map { chunk in
                        guard let toolCalls = chunk.toolCalls else { return chunk }
                        return chunk.withToolCalls(
                            toolCalls.map { ToolCall(id: $0.id, name: reverseMap[$0.name] ?? $0.name, arguments: $0.arguments) }
                        )
                    }
                }
                // 单个 SSE 事件可能产出多个 chunk（如思考与正文同 delta），
                // 必须逐个喂给累积器，否则会丢掉其中一段内容。
                for chunk in parsed {
                    guard await accumulator.consume(chunk, onChunk: onChunk) else { return false }
                }
                return true
            } catch {
                accumulator.fail(error)
                return false
            }
        }
        return try accumulator.finish(model: model)
    }

    // MARK: - Responses

    private func sendResponses(
        _ request: LLMRequest,
        model: String,
        apiKey: String
    ) async throws -> LLMResponse {
        if Self.verbose {
            Self.logger.debug("\(Self.t)sendResponses model=\(model, privacy: .public)")
        }
        var input = Self.responsesInput(from: request.messages)
        var body: [String: Any] = ["model": model, "input": input]

        // 注入工具定义，否则模型看不到任何可调用函数、只会返回纯文本。
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        if let tools, !tools.isEmpty {
            body["tools"] = tools.map(formatResponsesTool)
        }
        if let reasoningEffort = normalizedReasoningEffort(request.reasoningEffort) {
            body["reasoning"] = ["effort": reasoningEffort]
        }

        var httpRequest = URLRequest(url: try endpointURL("\(Self.base)/responses"))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        nonisolated(unsafe) let finalBody = body
        let data = try await apiService.sendJSON(request: httpRequest, body: finalBody)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let result = Self.responsesResult(from: object, reverseMap: reverseMap)
        let tokenCounts = Self.tokenCounts(from: data, anthropic: false)
        return LLMResponse(
            content: result.content,
            model: model,
            toolCalls: result.toolCalls?.map {
                LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            inputTokenCount: tokenCounts.input,
            outputTokenCount: tokenCounts.output,
            cachedInputTokenCount: tokenCounts.cachedInput,
            cacheWriteInputTokenCount: tokenCounts.cacheWrite,
            cacheTotalInputTokenCount: tokenCounts.cacheTotal
        )
    }

    /// Responses 协议的流式请求（issue #413）：模型元数据声明
    /// `supportsStreaming = true`，此前 streamComplete 却直接回落到一次性
    /// `sendResponses`，既不带 `stream: true` 也没有任何增量回调。
    private func streamResponses(
        _ request: LLMRequest,
        model: String,
        apiKey: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        if Self.verbose {
            Self.logger.debug("\(Self.t)streamResponses model=\(model, privacy: .public)")
        }
        var body: [String: Any] = [
            "model": model,
            "input": Self.responsesInput(from: request.messages),
            "stream": true,
        ]
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        if let tools, !tools.isEmpty {
            body["tools"] = tools.map(formatResponsesTool)
        }
        if let reasoningEffort = normalizedReasoningEffort(request.reasoningEffort) {
            body["reasoning"] = ["effort": reasoningEffort]
        }

        var httpRequest = URLRequest(url: try endpointURL("\(Self.base)/responses"))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let accumulator = GoStreamingAccumulator()
        nonisolated(unsafe) let finalBody = body
        try await apiService.sendStreamingChatRequest(request: httpRequest, body: finalBody) { data in
            let chunks = Self.responsesStreamChunks(from: data, reverseMap: reverseMap)
            for chunk in chunks {
                guard await accumulator.consume(chunk, onChunk: onChunk) else { return false }
            }
            return true
        }
        return try accumulator.finish(model: model)
    }

    /// 解析 Responses SSE 事件块。每个交付的 Data 是一个完整事件
    /// （`event:` + `data:` 行）；`data` JSON 自带 `type` 字段，缺失时回退
    /// `event:` 行。
    ///
    /// 工具调用只在 `response.output_item.done` 一次性收集完整参数——
    /// 增量 delta 仅用于 UI 无需流式展示参数，一次成块可避免与增量拼接
    /// 逻辑互相干扰。
    private nonisolated static func responsesStreamChunks(
        from data: Data,
        reverseMap: [String: String]?
    ) -> [StreamChunk] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var dataPayload = ""
        var eventName: String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("data:") {
                dataPayload += String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("event:") {
                eventName = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }
        guard !dataPayload.isEmpty, dataPayload != "[DONE]" else { return [] }
        guard let object = try? JSONSerialization.jsonObject(with: Data(dataPayload.utf8)) as? [String: Any] else {
            return []
        }
        let type = (object["type"] as? String) ?? eventName ?? ""

        switch type {
        case "response.output_text.delta":
            guard let delta = object["delta"] as? String, !delta.isEmpty else { return [] }
            return [StreamChunk(content: delta, eventType: .textDelta)]

        case "response.output_item.done":
            guard let item = object["item"] as? [String: Any],
                  item["type"] as? String == "function_call",
                  let name = item["name"] as? String else { return [] }
            let arguments = item["arguments"] as? String ?? "{}"
            let id = (item["call_id"] as? String) ?? (item["id"] as? String) ?? UUID().uuidString
            return [
                StreamChunk(
                    toolCalls: [
                        ToolCall(id: id, name: reverseMap?[name] ?? name, arguments: arguments)
                    ]
                )
            ]

        case "response.completed":
            guard let response = object["response"] as? [String: Any] else {
                return [StreamChunk(isDone: true)]
            }
            let usage = response["usage"] as? [String: Any]
            let input = usage?["input_tokens"] as? Int
            return [
                StreamChunk(
                    isDone: true,
                    inputTokens: input,
                    outputTokens: usage?["output_tokens"] as? Int,
                    cachedInputTokens: usage.flatMap { OpenAICompatibleProviderAdapter.cacheReadInputTokens(from: $0) },
                    cacheWriteInputTokens: usage.flatMap { OpenAICompatibleProviderAdapter.cacheWriteInputTokens(from: $0) },
                    cacheTotalInputTokens: input,
                    responseID: response["id"] as? String
                )
            ]

        case "response.incomplete":
            let reason = (object["response"] as? [String: Any])
                .flatMap { $0["incomplete_details"] as? [String: Any] }?["reason"] as? String
            return [StreamChunk(isDone: true, stopReason: reason ?? "incomplete")]

        case "response.failed", "error":
            return [StreamChunk(error: Self.responsesStreamErrorMessage(from: object))]

        default:
            return []
        }
    }

    /// 从失败事件的多种供应商形态里提取安全的错误文本。
    private nonisolated static func responsesStreamErrorMessage(from object: [String: Any]) -> String {
        let message =
            ((object["response"] as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
            ?? (object["error"] as? [String: Any])?["message"] as? String
            ?? object["message"] as? String
        return message ?? "Responses stream failed"
    }

    /// OpenCode 网关的不同协议使用不同的 usage 字段名，统一转换到 Lumi 的
    /// token 统计字段。
    ///
    /// 缓存字段复用共享的 OpenAI 适配器解析：Responses 的标准 usage 把
    /// 缓存命中写在 `input_tokens_details.cached_tokens`，该形态在仓库
    /// 其它路径已被支持，这里必须保持同一口径，否则缓存命中率统计会
    /// 把每一轮 Responses 请求都排除在外。
    private static func tokenCounts(
        from data: Data,
        anthropic: Bool
    ) -> (input: Int?, output: Int?, cachedInput: Int?, cacheWrite: Int?, cacheTotal: Int?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = object["usage"] as? [String: Any] else {
            return (nil, nil, nil, nil, nil)
        }
        let input: Int?
        let output: Int?
        if anthropic {
            input = usage["input_tokens"] as? Int
            output = usage["output_tokens"] as? Int
        } else {
            input = usage["input_tokens"] as? Int ?? usage["prompt_tokens"] as? Int
            output = usage["output_tokens"] as? Int ?? usage["completion_tokens"] as? Int
        }
        let cachedInput = OpenAICompatibleProviderAdapter.cacheReadInputTokens(from: usage)
        let cacheWrite = OpenAICompatibleProviderAdapter.cacheWriteInputTokens(from: usage)
        // OpenAI 形态的 `input_tokens` 已经是总输入（含缓存命中部分），
        // 不能与缓存字段相加。
        let cacheTotal = input
        return (input, output, cachedInput, cacheWrite, cacheTotal)
    }

    private func endpointURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw VendorAPIError.invalidBaseURL(string)
        }
        return url
    }

    /// Responses API 的 tools 项采用平铺结构（不像 chat 那样套一层 function）。
    private func formatResponsesTool(_ tool: any LLMToolSchemaProviding) -> [String: Any] {
        [
            "type": "function",
            "name": LLMToolNameSanitizer.sanitize(tool.name),
            "description": tool.toolDescription,
            "parameters": tool.inputSchema,
            "strict": false,
        ]
    }

    /// Responses 协议的历史序列化：历史里的工具调用名必须与工具定义同样
    /// sanitize——解析时按 reverseMap 还原成注册名，回传时写回 sanitize 名，
    /// 否则端点看到的 function_call 与 tools 定义名称不一致。工具结果必须
    /// 以 function_call_output（带 call_id）回传，而不是普通 role:text 项——
    /// 否则第二轮工具循环无法重建（issue #285）。
    private static func responsesInput(from messages: [LLMMessage]) -> [[String: Any]] {
        var input: [[String: Any]] = []
        for message in messages {
            if message.role == .assistant, let calls = message.toolCalls, !calls.isEmpty {
                if !message.content.isEmpty {
                    input.append(["role": message.role.rawValue, "content": message.content])
                }
                for call in calls {
                    let name = LLMToolNameSanitizer.sanitize(call.name)
                    input.append([
                        "type": "function_call",
                        "call_id": call.id,
                        "name": name,
                        "arguments": call.arguments,
                    ])
                }
                continue
            }
            if message.role == .tool, let callID = message.toolCallID {
                input.append([
                    "type": "function_call_output",
                    "call_id": callID,
                    "output": message.content,
                ])
                continue
            }
            input.append(["role": message.role.rawValue, "content": message.content])
        }
        return input
    }

    /// 从 Responses 响应中提取正文文本与工具调用。
    /// 工具名经 `formatResponsesTool` sanitize，这里按 reverseMap 还原成注册 id。
    private static func responsesResult(
        from object: [String: Any],
        reverseMap: [String: String]?
    ) -> (content: String, toolCalls: [LLMToolCall]?) {
        if let text = object["output_text"] as? String, !text.isEmpty {
            return (text, responsesFunctionCalls(from: object, reverseMap: reverseMap))
        }
        guard let output = object["output"] as? [[String: Any]] else {
            return ("", nil)
        }
        var content = ""
        var calls: [LLMToolCall] = []
        for item in output {
            if let text = item["content"] as? String {
                content += text
            } else if let blocks = item["content"] as? [[String: Any]] {
                content += blocks.compactMap { $0["text"] as? String }.joined()
            }
            if item["type"] as? String == "function_call",
               let name = item["name"] as? String,
               let arguments = item["arguments"] as? String {
                let id = (item["call_id"] as? String) ?? (item["id"] as? String) ?? UUID().uuidString
                calls.append(LLMToolCall(
                    id: id,
                    name: reverseMap?[name] ?? name,
                    arguments: arguments
                ))
            }
        }
        return (content, calls.isEmpty ? nil : calls)
    }

    private static func responsesFunctionCalls(
        from object: [String: Any],
        reverseMap: [String: String]?
    ) -> [LLMToolCall]? {
        guard let output = object["output"] as? [[String: Any]] else { return nil }
        var calls: [LLMToolCall] = []
        for item in output where item["type"] as? String == "function_call" {
            guard let name = item["name"] as? String,
                  let arguments = item["arguments"] as? String else { continue }
            let id = (item["call_id"] as? String) ?? (item["id"] as? String) ?? UUID().uuidString
            calls.append(LLMToolCall(
                id: id,
                name: reverseMap?[name] ?? name,
                arguments: arguments
            ))
        }
        return calls.isEmpty ? nil : calls
    }
}

/// 累积 OpenCode 流式响应中的正文、推理内容和工具调用分片。
///
/// OpenAI-compatible 网关通常会把工具名称、调用 ID 和 arguments 分成多个
/// SSE chunk 返回；如果只处理 content，最终响应会被误判成空的纯文本响应。
private final class GoStreamingAccumulator: @unchecked Sendable {
    private var content = ""
    private var reasoningContent = ""
    private var toolCalls: [Int: ToolCall] = [:]
    private var toolCallOrder: [Int] = []
    private var inputTokens: Int?
    private var outputTokens: Int?
    private var cachedInputTokens: Int?
    private var cacheWriteInputTokens: Int?
    private var cacheTotalInputTokens: Int?
    private var responseID: String?
    private var stopReason: String?
    private var finished = false
    private var failure: Error?

    func consume(
        _ chunk: StreamChunk,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async -> Bool {
        if failure != nil { return false }

        if let error = chunk.error {
            failure = VendorAPIError.requestFailed(error)
            return false
        }

        if let inputTokens = chunk.inputTokens {
            self.inputTokens = inputTokens
        }
        if let outputTokens = chunk.outputTokens {
            self.outputTokens = outputTokens
        }
        if let cachedInputTokens = chunk.cachedInputTokens {
            self.cachedInputTokens = cachedInputTokens
        }
        if let cacheWriteInputTokens = chunk.cacheWriteInputTokens {
            self.cacheWriteInputTokens = cacheWriteInputTokens
        }
        if let cacheTotalInputTokens = chunk.cacheTotalInputTokens {
            self.cacheTotalInputTokens = cacheTotalInputTokens
        }
        if let responseID = chunk.responseID {
            self.responseID = responseID
        }
        if let stopReason = chunk.stopReason {
            self.stopReason = stopReason
            // Some OpenAI-compatible gateways omit [DONE] but provide an
            // explicit finish_reason. Treat that as a valid terminator.
            finished = true
        }

        if chunk.eventType == .thinkingDelta, let piece = chunk.content, !piece.isEmpty {
            reasoningContent += piece
            await onChunk(LLMStreamChunk(reasoningContent: piece))
        } else if let piece = chunk.content, !piece.isEmpty {
            content += piece
            await onChunk(LLMStreamChunk(content: piece))
        }

        if let calls = chunk.toolCalls, !calls.isEmpty {
            for call in calls {
                let index = chunk.toolCallIndex ?? nextIndex()
                upsertToolCall(index: index, call: call)
            }
        } else if let partialJson = chunk.partialJson, !partialJson.isEmpty {
            let index = chunk.toolCallIndex ?? toolCallOrder.last ?? 0
            upsertArguments(index: index, fragment: partialJson)
        }

        if chunk.isDone {
            finished = true
            return false
        }
        return true
    }

    func finish(model: String) throws -> LLMResponse {
        if let failure { throw failure }
        guard finished else { throw VendorAPIError.incompleteStream }
        let calls = toolCallOrder.compactMap { toolCalls[$0] }
        let response = LLMResponse(
            content: content,
            model: model,
            toolCalls: calls.isEmpty ? nil : calls.map {
                LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: reasoningContent.isEmpty ? nil : reasoningContent,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            cachedInputTokenCount: cachedInputTokens,
            cacheWriteInputTokenCount: cacheWriteInputTokens,
            cacheTotalInputTokenCount: cacheTotalInputTokens,
            responseID: responseID,
            stopReason: stopReason
        )
        try response.validateToolCallArguments()
        return response
    }

    func fail(_ error: Error) {
        failure = error
    }

    private func nextIndex() -> Int {
        toolCallOrder.last.map { $0 + 1 } ?? 0
    }

    private func upsertToolCall(index: Int, call: ToolCall) {
        if let existing = toolCalls[index] {
            toolCalls[index] = ToolCall(
                id: existing.id.isEmpty ? call.id : existing.id,
                name: existing.name.isEmpty ? call.name : existing.name,
                arguments: existing.arguments == "{}" ? call.arguments : existing.arguments + call.arguments
            )
        } else {
            toolCalls[index] = call
            if !toolCallOrder.contains(index) {
                toolCallOrder.append(index)
            }
        }
    }

    private func upsertArguments(index: Int, fragment: String) {
        if let existing = toolCalls[index] {
            let existingArguments = existing.arguments == "{}" ? "" : existing.arguments
            toolCalls[index] = ToolCall(
                id: existing.id,
                name: existing.name,
                arguments: existingArguments + fragment
            )
        } else {
            toolCalls[index] = ToolCall(id: "", name: "", arguments: fragment)
            if !toolCallOrder.contains(index) {
                toolCallOrder.append(index)
            }
        }
    }
}
