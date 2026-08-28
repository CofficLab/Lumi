import Foundation
import KitLLM
import os
import ProviderLLMManager
import KitSuperLog

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
            return try await sendResponses(request, model: model, apiKey: apiKey)
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
                config: LLMConfig(model: model, providerId: providerInfo.id)
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
                    return false
                }
            }
            return accumulator.finish(model: model)
        }

        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(baseURL: Self.base, includeUsageInStreamOptions: true)
        )
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: request.messages,
            model: model,
            tools: tools,
            systemPrompt: "",
            config: LLMConfig(model: model, providerId: providerInfo.id)
        )
        let accumulator = GoStreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL("\(Self.base)/chat/completions"), apiKey: apiKey),
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
                return false
            }
        }
        return accumulator.finish(model: model)
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
        var input: [[String: Any]] = []
        for message in request.messages {
            input.append(["role": message.role.rawValue, "content": message.content])
        }
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
            outputTokenCount: tokenCounts.output
        )
    }

    /// OpenCode 网关的不同协议使用不同的 usage 字段名，统一转换到 Lumi 的
    /// token 统计字段。
    private static func tokenCounts(from data: Data, anthropic: Bool) -> (input: Int?, output: Int?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = object["usage"] as? [String: Any] else {
            return (nil, nil)
        }
        if anthropic {
            return (
                usage["input_tokens"] as? Int,
                usage["output_tokens"] as? Int
            )
        }
        return (
            usage["input_tokens"] as? Int ?? usage["prompt_tokens"] as? Int,
            usage["output_tokens"] as? Int ?? usage["completion_tokens"] as? Int
        )
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

    func consume(
        _ chunk: StreamChunk,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async -> Bool {
        if let inputTokens = chunk.inputTokens {
            self.inputTokens = inputTokens
        }
        if let outputTokens = chunk.outputTokens {
            self.outputTokens = outputTokens
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

        return !chunk.isDone
    }

    func finish(model: String) -> LLMResponse {
        let calls = toolCallOrder.compactMap { toolCalls[$0] }
        return LLMResponse(
            content: content,
            model: model,
            toolCalls: calls.isEmpty ? nil : calls.map {
                LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: reasoningContent.isEmpty ? nil : reasoningContent,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens
        )
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
