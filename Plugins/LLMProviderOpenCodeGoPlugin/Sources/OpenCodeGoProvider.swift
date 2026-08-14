import Foundation
import KernelLumi
import LLMKit

public final class OpenCodeGoProvider: LumiLLMProvider, @unchecked Sendable {
    /// API 协议类型，决定请求走哪个端点
    private enum Kind {
        case responses
        case openAI
        case anthropic
    }

    /// 单个模型的静态配置
    private struct Model {
        let id: String
        let name: String
        let kind: Kind
        var contextWindowSize: Int? = nil
    }

    private static let base = "https://opencode.ai/zen/go/v1"

    private static let models: [Model] = [
        // Responses API
        .init(id: "grok-4.5", name: "Grok 4.5", kind: .responses),
        .init(id: "gpt-5.6-luna", name: "GPT 5.6 Luna", kind: .responses),

        // OpenAI-compatible
        .init(id: "glm-5.3", name: "GLM-5.3", kind: .openAI),
        .init(id: "glm-5.2", name: "GLM-5.2", kind: .openAI),
        .init(id: "glm-5.1", name: "GLM-5.1", kind: .openAI),
        .init(id: "kimi-k3", name: "Kimi K3", kind: .openAI),
        .init(id: "kimi-k2.7-code", name: "Kimi K2.7 Code", kind: .openAI),
        .init(id: "kimi-k2.6", name: "Kimi K2.6", kind: .openAI),
        .init(id: "mimo-v2.5", name: "MiMo-V2.5", kind: .openAI),
        .init(id: "mimo-v2.5-pro", name: "MiMo-V2.5-Pro", kind: .openAI),
        .init(id: "deepseek-v4-pro", name: "DeepSeek V4 Pro", kind: .openAI),
        .init(id: "deepseek-v4-flash", name: "DeepSeek V4 Flash", kind: .openAI, contextWindowSize: 1_000_000),
        .init(id: "hy3", name: "Hy3", kind: .openAI),

        // Anthropic-compatible
        .init(id: "minimax-m3", name: "MiniMax M3", kind: .anthropic),
        .init(id: "minimax-m2.7", name: "MiniMax M2.7", kind: .anthropic),
        .init(id: "minimax-m2.5", name: "MiniMax M2.5", kind: .anthropic),
        .init(id: "qwen3.8-max", name: "Qwen3.8 Max", kind: .anthropic),
        .init(id: "qwen3.7-max", name: "Qwen3.7 Max", kind: .anthropic),
        .init(id: "qwen3.7-plus", name: "Qwen3.7 Plus", kind: .anthropic),
        .init(id: "qwen3.6-plus", name: "Qwen3.6 Plus", kind: .anthropic),
    ]

    public static let info = LumiLLMProviderInfo(
        id: "opencode-go",
        displayName: "OpenCode Go",
        description: "低成本的开源编程模型订阅服务",
        defaultModel: "deepseek-v4-flash",
        availableModels: models.map { model in
            LumiModelInfo(
                id: model.id,
                displayName: model.name,
                contextWindowSize: model.contextWindowSize,
                capabilities: .init(supportsVision: false, supportsTools: true)
            )
        },
        websiteURL: URL(string: "https://opencode.ai/docs/zh-cn/go/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_OpenCodeGo"
    )

    public var providerInfo: LumiLLMProviderInfo { Self.info }

    private let api: LLMAPIService
    private var keyName: String { Self.info._apiKeyStorageKey! }

    /// - Parameter apiService: 底层 HTTP 传输。默认走 `HTTPClient`；传入
    ///   `LLMAPIService(kernel:)` 时由 NetworkManagerPlugin 的
    ///   `NetworkProviding` 承载，请求会进入 HTTP 交换记录。
    public init(apiService: LLMAPIService = LLMAPIService()) {
        self.api = apiService
    }

    // MARK: - API Key

    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(storageKey: keyName, displayName: Self.info.displayName)
    }

    public func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: keyName)
    }

    public func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: keyName)
    }

    public func setApiKey(_ value: String) {
        LumiAPIKeyTools.set(value, storageKey: keyName)
    }

    public func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: keyName)
    }

    // MARK: - 状态与错误

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        hasApiKey() ? .available : .unavailable(.message("未配置 API Key"))
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        hasApiKey()
            ? nil
            : LumiLLMProviderStatusSupport.missingAPIKeyStatus(providerName: Self.info.displayName)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .retryable()
    }

    public func errorRenderKind(for error: Error) -> String? {
        nil
    }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: Self.info.id,
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: nil
        )
    }

    // MARK: - 发送请求

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let m = try await send(request)
        if !m.content.isEmpty {
            await onChunk(.init(content: m.content, isDone: false))
        }
        await onChunk(.init(content: nil, isDone: true))
        return m
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        guard let model = Self.models.first(where: { $0.id == request.model }) else {
            throw LumiLLMProviderSupportError.emptyResponse
        }
        let started = Date()
        var m: LumiChatMessage
        switch model.kind {
        case .openAI:
            m = try await chat(request, anthropic: false)
        case .anthropic:
            m = try await chat(request, anthropic: true)
        case .responses:
            m = try await responses(request)
        }
        // 非流式 provider：整体耗时即用户等待时长，首个 token 与全部内容同时到达，
        // 因此 TTFT = 总耗时；streamingDurationMs 保持 nil（不存在流式阶段）。
        let latency = Date().timeIntervalSince(started) * 1000
        m.latencyMs = latency
        m.timeToFirstTokenMs = latency
        return m
    }

    private func url(_ path: String) throws -> URL {
        guard let u = URL(string: "\(Self.base)/\(path)") else {
            throw LumiLLMProviderSupportError.invalidBaseURL(Self.base)
        }
        return u
    }

    /// 非流式响应的 token 用量统计（对应响应中的 `usage` 字段）。
    struct TokenUsage {
        var inputTokens: Int?
        var outputTokens: Int?
        var cachedInputTokens: Int?
        var cacheWriteInputTokens: Int?
        var cacheTotalInputTokens: Int?
    }

    private func message(
        _ r: LumiLLMRequest,
        _ text: String,
        _ calls: [LumiToolCall]? = nil,
        usage: TokenUsage? = nil
    ) -> LumiChatMessage {
        // 参照 DeepSeek 插件：input/output 直接落到专用字段，缓存明细写入 metadata，
        // 二者都会被 MessageStore 持久化到数据库（metadata 以 JSON 形式落库）。
        var metadata: [String: String] = [:]
        if let usage {
            let usageMetadata = MessageTokenMetadata.metadata(
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                cachedInputTokens: usage.cachedInputTokens,
                cacheWriteInputTokens: usage.cacheWriteInputTokens,
                cacheTotalInputTokens: usage.cacheTotalInputTokens
            )
            // 已有 metadata 中的同名 key 优先保留（与 DeepSeek toLumiChatMessage 语义一致）
            metadata.merge(usageMetadata) { existing, _ in existing }
        }
        return .init(
            conversationID: r.messages.first?.conversationID ?? UUID(),
            role: .assistant,
            content: text,
            providerID: Self.info.id,
            modelName: r.model,
            metadata: metadata,
            toolCalls: calls,
            inputTokenCount: usage?.inputTokens,
            outputTokenCount: usage?.outputTokens
        )
    }

    /// 从非流式 JSON 响应体提取 `usage` 统计。
    ///
    /// 兼容 opencode.go 三种协议端点：
    /// - OpenAI-compatible：`usage.prompt_tokens` / `completion_tokens` /
    ///   `prompt_cache_hit_tokens` / `prompt_tokens_details.cached_tokens`
    /// - Anthropic-compatible：`usage.input_tokens` / `output_tokens` /
    ///   `cache_read_input_tokens` / `cache_creation_input_tokens`
    /// - Responses API：`usage.input_tokens` / `output_tokens` /
    ///   `input_tokens_details.cached_tokens`
    ///
    /// `cacheTotalInputTokens` 语义：Anthropic 风格 input_tokens 不含缓存命中部分，
    /// 须累加 cache_read + cache_write；Responses 风格 input_tokens 已含缓存命中，
    /// 直接用 input_tokens 即可（与 DeepSeek 插件的合并规则一致）。
    func tokenUsage(from data: Data) -> TokenUsage {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let usage = json["usage"] as? [String: Any] else {
            return TokenUsage()
        }

        // OpenAI-compatible
        if let prompt = usage["prompt_tokens"] as? Int {
            let hit = usage["prompt_cache_hit_tokens"] as? Int
            let miss = usage["prompt_cache_miss_tokens"] as? Int
            let detailsCached = (usage["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
            let cached = hit ?? detailsCached
            return TokenUsage(
                inputTokens: prompt,
                outputTokens: usage["completion_tokens"] as? Int,
                cachedInputTokens: cached,
                cacheWriteInputTokens: nil,
                cacheTotalInputTokens: hit.flatMap { h in miss.map { h + $0 } } ?? prompt
            )
        }

        // Anthropic-compatible / Responses API
        if let input = usage["input_tokens"] as? Int {
            let details = usage["input_tokens_details"] as? [String: Any]
            let responsesCached = details?["cached_tokens"] as? Int
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? responsesCached
            let cacheWrite = usage["cache_creation_input_tokens"] as? Int
            let total: Int? = responsesCached != nil
                ? input
                : input + (cacheRead ?? 0) + (cacheWrite ?? 0)
            return TokenUsage(
                inputTokens: input,
                outputTokens: usage["output_tokens"] as? Int,
                cachedInputTokens: cacheRead,
                cacheWriteInputTokens: cacheWrite,
                cacheTotalInputTokens: total
            )
        }

        return TokenUsage()
    }

    private func chat(_ r: LumiLLMRequest, anthropic: Bool) async throws -> LumiChatMessage {
        let ms = LumiLLMRequestMessages.preparedForProvider(r)
        let tools = r.tools.map(LumiToolSchema.init)

        if anthropic {
            let a = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
            let body = try a.buildRequestBody(messages: ms, model: r.model, tools: tools, systemPrompt: "")
            let data = try await api.sendChatRequest(
                request: a.buildRequest(url: try url("messages"), apiKey: try lumiResolveAPIKey()),
                body: body
            )
            let p = try a.parseResponse(data: data)
            return message(
                r,
                p.content,
                p.toolCalls?.map { .init(id: $0.id, name: $0.name, arguments: $0.arguments) },
                usage: tokenUsage(from: data)
            )
        }

        let a = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
        let body = try a.buildRequestBody(messages: ms, model: r.model, tools: tools, systemPrompt: "")
        let data = try await api.sendChatRequest(
            request: a.buildRequest(url: try url("chat/completions"), apiKey: try lumiResolveAPIKey()),
            body: body
        )
        let p = try a.parseResponse(data: data)
        return message(
            r,
            p.content,
            p.toolCalls?.map { .init(id: $0.id, name: $0.name, arguments: $0.arguments) },
            usage: tokenUsage(from: data)
        )
    }

    private func responses(_ r: LumiLLMRequest) async throws -> LumiChatMessage {
        let input = LumiLLMRequestMessages.preparedForProvider(r).map { ["role": $0.role.rawValue, "content": $0.content] as [String: Any] }
        var body: [String: Any] = ["model": r.model, "input": input]
        if !r.tools.isEmpty {
            body["tools"] = r.tools.map { ["type": "function", "name": $0.name, "description": $0.toolDescription, "parameters": $0.inputSchema.anyValue] }
        }

        var req = URLRequest(url: try url("responses"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await api.sendChatRequest(request: req, body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let output = object["output"] as? [[String: Any]] ?? []
        let text = (object["output_text"] as? String) ?? output
            .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["text"] as? String }
            .joined()
        let calls = output
            .filter { $0["type"] as? String == "function_call" }
            .compactMap { x -> LumiToolCall? in
                guard let id = x["call_id"] as? String ?? x["id"] as? String,
                      let n = x["name"] as? String else { return nil }
                return .init(id: id, name: n, arguments: x["arguments"] as? String ?? "{}")
            }
        return message(r, text, calls.isEmpty ? nil : calls, usage: tokenUsage(from: data))
    }
}
