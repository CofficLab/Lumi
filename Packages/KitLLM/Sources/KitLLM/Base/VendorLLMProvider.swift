import Foundation
import os

/// LLM 供应商基类（零项目依赖，纯系统框架实现）。
///
/// 子类只需提供：
/// - `providerInfo`（模型列表、协议格式、API Key storage key）
/// - `openAIConfiguration` 或 `anthropicConfiguration`（对应协议的端点配置）
///
/// 模型列表获取策略由子类自行决定：
/// - 静态子类：使用默认 `availableModels`（返回 `providerInfo.models`）。
/// - 远程子类：override `availableModels` / `refreshModels`，在供应商包内
///   自行实现请求/解析/合并逻辑（每个供应商格式可能不同）。
@MainActor
open class VendorLLMProvider: SuperLLMProvider, LLMStreamingProviding {

    nonisolated public static let logger = Logger(subsystem: "com.kit.llm", category: "VendorLLMProvider")

    public let providerInfo: LLMProviderInfo
    public let apiService: VendorAPIService

    /// OpenAI 兼容协议适配器配置（子类覆盖）。
    open var openAIConfiguration: OpenAICompatibleProviderConfiguration? { nil }

    /// Anthropic 兼容协议适配器配置（子类覆盖）。
    open var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? { nil }

    public init(info: LLMProviderInfo, apiService: VendorAPIService = VendorAPIService()) {
        self.providerInfo = info
        self.apiService = apiService
    }

    public var providerID: String { providerInfo.id }

    // MARK: - 模型列表（默认静态实现；子类自行 override 决定获取策略）

    /// 默认静态实现：模型列表来自注册时的 `providerInfo.models`。
    ///
    /// 以 `open` 声明（而非协议扩展默认），保证远程子类的 override
    /// 能通过 `any SuperLLMProvider` 动态派发到。
    open var availableModels: [LLMModelInfo] { providerInfo.models }

    /// 默认空操作（静态供应商无远程源）。
    open func refreshModels() async throws {}

    /// 默认无远程模型源。
    open var usesRemoteModelList: Bool { false }

    /// 默认无同步记录。
    open var lastModelSyncDate: Date? { nil }

    // MARK: - LLMProviding

    open func complete(_ request: LLMRequest) async throws -> LLMResponse {
        switch providerInfo.apiFormat {
        case .openAI:
            return try await sendOpenAI(request)
        case .anthropic:
            return try await sendAnthropic(request)
        case .responses:
            return try await sendResponses(request)
        }
    }

    // MARK: - LLMStreamingProviding

    open func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        switch providerInfo.apiFormat {
        case .openAI:
            return try await streamOpenAI(request, onChunk: onChunk)
        case .anthropic:
            return try await streamAnthropic(request, onChunk: onChunk)
        case .responses:
            return try await complete(request)
        }
    }

    // MARK: - API Key
    //
    // 以下五个方法以 `open` 声明（而非 `public`），理由同 `availableModels`：
    // 子类需要覆盖它们才能保证动态派发到覆盖实现。典型场景是 UI 测试专用
    // 供应商——它必须在**完全不碰 Keychain** 的前提下返回一个固定假 Key，
    // 否则 UI 测试会因 Keychain 授权弹窗而阻塞，或因未配置 Key 而稳定失败。

    open func hasApiKey() -> Bool {
        VendorAPIKeyTools.has(storageKey: providerInfo.apiKeyStorageKey)
    }

    open func getApiKey() -> String {
        VendorAPIKeyTools.get(storageKey: providerInfo.apiKeyStorageKey)
    }

    open func setApiKey(_ apiKey: String) {
        VendorAPIKeyTools.set(apiKey, storageKey: providerInfo.apiKeyStorageKey)
    }

    open func setApiKeyReportingErrors(_ apiKey: String) throws {
        try VendorAPIKeyTools.setReportingErrors(apiKey, storageKey: providerInfo.apiKeyStorageKey)
    }

    open func removeApiKey() {
        VendorAPIKeyTools.remove(storageKey: providerInfo.apiKeyStorageKey)
    }

    open func resolveAPIKey() throws -> String {
        try VendorAPIKeyTools.resolve(
            storageKey: providerInfo.apiKeyStorageKey,
            displayName: providerInfo.displayName
        )
    }

    // MARK: - OpenAI (non-streaming)

    private func sendOpenAI(_ request: LLMRequest) async throws -> LLMResponse {
        guard let configuration = openAIConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 OpenAI 端点")
        }
        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        let model = request.model ?? providerInfo.defaultModel
        // 请求体构建与 JSON 序列化都在后台线程完成：这一步要遍历全部历史
        // 消息、编码历史图片，放在主线程上会卡住 UI（Issue #1269）。
        let bodyData = try await RequestBodyBuilder.openAIBody(
            messages: request.messages,
            model: model,
            tools: tools,
            config: makeConfig(model: model, request: request),
            configuration: configuration
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            bodyData: bodyData
        )
        // 响应解析在后台线程完成：这一步要解码整份响应，并解开内联
        // 生成图片的 base64（一张 1.5 MB 的图约 1.6 ms）。放在主线程上
        // 会卡住滚动与输入（Issue #1270）。
        //
        // 必须用 `Task.detached`：实测直接调用与 `Task {}`（继承 actor
        // 上下文）都仍在主线程上执行，只有 `Task.detached` 才会真正离开。
        let parsed = try await Task.detached(priority: .userInitiated) {
            try adapter.parseResponse(data: data, reverseMap: reverseMap)
        }.value
        // token 用量随响应一起解码，不再把同一份响应重新解析一遍
        // （Issue #1270）。
        let tokenCounts = parsed.tokenUsage
        return LLMResponse(
            content: parsed.content,
            model: model,
            toolCalls: parsed.toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            reasoningContent: parsed.reasoningContent,
            inputTokenCount: tokenCounts.input,
            outputTokenCount: tokenCounts.output,
            cachedInputTokenCount: tokenCounts.cachedInput,
            cacheWriteInputTokenCount: tokenCounts.cacheWrite,
            cacheTotalInputTokenCount: tokenCounts.cacheTotal,
            // 响应元数据：供应商的关联 ID 与结束原因。截断的回答（`length`）
            // 靠 `stopReason` 才能说明「为什么没说完」。
            responseID: parsed.responseID,
            stopReason: parsed.stopReason,
            // 生成的图片（图像生成模型的产物）。没有它，一次合法的
            // 「只生成图片」的响应会被当成空响应。
            images: parsed.images
        )
    }

    // MARK: - Anthropic (non-streaming)

    private func sendAnthropic(_ request: LLMRequest) async throws -> LLMResponse {
        guard let configuration = anthropicConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 Anthropic 端点")
        }
        let adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        let model = request.model ?? providerInfo.defaultModel
        // 请求体构建与 JSON 序列化都在后台线程完成（Issue #1269）。
        let bodyData = try await RequestBodyBuilder.anthropicBody(
            messages: request.messages,
            model: model,
            tools: tools,
            config: makeConfig(model: model, request: request),
            configuration: configuration
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            bodyData: bodyData
        )
        // 响应解析在后台线程完成：这一步要解码整份响应，并解开内联
        // 生成图片的 base64（一张 1.5 MB 的图约 1.6 ms）。放在主线程上
        // 会卡住滚动与输入（Issue #1270）。
        //
        // 必须用 `Task.detached`：实测直接调用与 `Task {}`（继承 actor
        // 上下文）都仍在主线程上执行，只有 `Task.detached` 才会真正离开。
        let parsed = try await Task.detached(priority: .userInitiated) {
            try adapter.parseResponse(data: data, reverseMap: reverseMap)
        }.value
        // token 用量随响应一起解码，不再把同一份响应重新解析一遍
        // （Issue #1270）。
        let tokenCounts = parsed.tokenUsage
        return LLMResponse(
            content: parsed.content,
            model: model,
            toolCalls: parsed.toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            // 不透明 redacted_thinking 块：非流式与 SSE 必须同样保留，
            // 否则下一轮请求无法回传原始块（#1167）。
            redactedThinking: parsed.redactedThinking.isEmpty ? nil : parsed.redactedThinking,
            inputTokenCount: tokenCounts.input,
            outputTokenCount: tokenCounts.output,
            cachedInputTokenCount: tokenCounts.cachedInput,
            cacheWriteInputTokenCount: tokenCounts.cacheWrite,
            cacheTotalInputTokenCount: tokenCounts.cacheTotal,
            // 响应 ID 与停止原因：与 SSE 路径同源，避免两条协议路径给出
            // 不一样的响应元数据。
            responseID: parsed.responseID,
            stopReason: parsed.stopReason
        )
    }

    // MARK: - Responses (OpenAI Responses protocol)

    private func sendResponses(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        var input: [[String: Any]] = []
        for message in request.messages {
            input.append(["role": message.role.rawValue, "content": message.content])
        }
        var body: [String: Any] = ["model": model, "input": input]
        if let reasoningEffort = normalizedReasoningEffort(request.reasoningEffort) {
            body["reasoning"] = ["effort": reasoningEffort]
        }

        var httpRequest = URLRequest(url: try endpointURL(responsesEndpointURL))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try resolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await apiService.sendJSON(request: httpRequest, body: body)
        // 响应解析在后台线程完成。
        //
        // `JSONSerialization` 把整份响应解析成 `Any` 字典树，成本与响应
        // 体积成正比；放在主线程上会卡住滚动与输入（Issue #1270）。
        //
        // `[String: Any]` 不满足 `Sendable`，因此**全部**提取工作都在后台
        // 完成，只把纯值结果带回来。
        //
        // 必须用 `Task.detached`：实测直接调用与 `Task {}`（继承 actor
        // 上下文）都仍在主线程上执行，只有 `Task.detached` 才会真正离开。
        let extracted = try await Task.detached(priority: .userInitiated) { () -> ResponsesExtraction in
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            // 终态失败必须被识别为供应商失败。
            //
            // Responses 协议用 `status: "failed"` + `error` 表达终态失败，且它
            // 走 HTTP 200。解析器此前从不检查这两个字段，于是失败的响应被当成
            // 「成功但内容为空」——没有 output 时 AgentLoop 报通用的、不可恢复
            // 的 `emptyResponse`，供应商给的错误全部丢失；有部分文本时甚至会
            // 被当成成功的助手消息落库。
            try Self.throwIfResponsesFailed(object)
            let text = Self.responsesText(from: object)
            // usage 直接从上面那次 `JSONSerialization` 的结果里读，不再把
            // 同一份响应重新解析一遍（Issue #1270）。
            let usage = self.tokenCounts(from: object["usage"] as? [String: Any], anthropic: false)
            return ResponsesExtraction(
                text: text,
                responseID: object["id"] as? String,
                inputTokens: usage.input,
                outputTokens: usage.output,
                cachedInputTokens: usage.cachedInput,
                cacheWriteTokens: usage.cacheWrite,
                cacheTotalInputTokens: usage.cacheTotal
            )
        }.value
        return LLMResponse(
            content: extracted.text,
            model: model,
            inputTokenCount: extracted.inputTokens,
            outputTokenCount: extracted.outputTokens,
            cachedInputTokenCount: extracted.cachedInputTokens,
            cacheWriteInputTokenCount: extracted.cacheWriteTokens,
            cacheTotalInputTokenCount: extracted.cacheTotalInputTokens,
            // 顶层响应 ID（`resp_...`）：供应商的关联标识，下游要靠它把一次
            // 请求与它的日志对上。自定义 `.responses` 供应商走的就是这条
            // 路径，丢掉它就无法在下游恢复（issue #1147）。
            responseID: extracted.responseID
        )
    }

    open var responsesEndpointURL: String { "https://api.openai.com/v1/responses" }

    // MARK: - OpenAI (streaming)

    private func streamOpenAI(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        guard let configuration = openAIConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 OpenAI 端点")
        }
        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        let model = request.model ?? providerInfo.defaultModel
        // 请求体构建与 JSON 序列化都在后台线程完成：这一步要遍历全部历史
        // 消息、编码历史图片，放在主线程上会卡住 UI（Issue #1269）。
        let bodyData = try await RequestBodyBuilder.openAIStreamingBody(
            messages: request.messages,
            model: model,
            tools: tools,
            config: makeConfig(model: model, request: request),
            configuration: configuration
        )

        let accumulator = StreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            bodyData: bodyData
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
                // 单个 SSE 事件可产出多个 chunk（思考与正文同 delta 时的
                // interleaved thinking 形态），必须逐个喂给累积器；
                // 只要有任一 chunk 请求终止，就停止读取后续事件。
                for chunk in parsed {
                    guard await accumulator.consume(chunk, onChunk: onChunk) else { return false }
                }
                return true
            } catch {
                accumulator.fail(error)
                return false
            }
        }
        return try await accumulator.finish(model: model)
    }

    // MARK: - Anthropic (streaming)

    private func streamAnthropic(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        guard let configuration = anthropicConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 Anthropic 端点")
        }
        let adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        let model = request.model ?? providerInfo.defaultModel
        // 请求体构建与 JSON 序列化都在后台线程完成（Issue #1269）。
        let bodyData = try await RequestBodyBuilder.anthropicStreamingBody(
            messages: request.messages,
            model: model,
            tools: tools,
            config: makeConfig(model: model, request: request),
            configuration: configuration
        )

        let accumulator = StreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            bodyData: bodyData
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
        return try await accumulator.finish(model: model)
    }

    // MARK: - Helpers

    /// 把请求级工具 schema（`[LLMFunctionSchema]`）转成适配器可消费的
    /// `[any LLMToolSchemaProviding]`，并构建工具名 sanitize 的 reverseMap，
    /// 供响应解析时把下划线还原成注册 id。子类（如 GoProvider）覆写协议路由时
    /// 必须复用此方法注入 tools，否则工具定义会丢失。
    public func toolSchemas(from schemas: [LLMFunctionSchema]?)
        -> ([any LLMToolSchemaProviding]?, [String: String]?) {
        guard let schemas, !schemas.isEmpty else { return (nil, nil) }
        var reverseMap: [String: String] = [:]
        let adapted: [AdapterToolSchema] = schemas.map { schema in
            reverseMap[LLMToolNameSanitizer.sanitize(schema.name)] = schema.name
            return AdapterToolSchema(schema)
        }
        return (adapted, reverseMap)
    }

    private func makeConfig(model: String, request: LLMRequest) -> LLMConfig {
        LLMConfig(
            model: model,
            providerId: providerInfo.id,
            temperature: nil,
            maxTokens: nil,
            reasoningEffort: normalizedReasoningEffort(request.reasoningEffort),
            reasoningOff: request.reasoningOff,
            reasoningCapability: reasoningCapability(for: model)
        )
    }

    /// 模型声明的思考能力；模型未声明时返回 `nil`（按通用行为处理）。
    ///
    /// 能力来自模型池（含远程刷新后的快照），因此供应商新增模型时，
    /// 「关闭思考」的真实语义与 UI 提示都跟着模型走。
    private func reasoningCapability(for model: String) -> LLMReasoningCapability? {
        availableModels.first { $0.id == model }?.reasoning
    }

    /// 归一化推理档位字符串，供子类覆写协议路由时复用（如 GoProvider 的 Responses 路径）。
    public func normalizedReasoningEffort(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["minimal", "low", "medium", "high", "xhigh", "max"].contains(normalized) else { return nil }
        return normalized
    }

    private func endpointURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw VendorAPIError.invalidBaseURL(string)
        }
        return url
    }

    /// Responses 响应若是终态失败，抛出供应商给出的错误。
    ///
    /// 失败信息优先取 `error.message`，其次取 `error.code`；两者都没有时用
    /// 状态值兜底，保证错误永远带得出一条可读的原因。
    private nonisolated static func throwIfResponsesFailed(_ object: [String: Any]) throws {
        guard let status = object["status"] as? String, status == "failed" else { return }
        let error = object["error"] as? [String: Any]
        let message = error?["message"] as? String
        let code = error?["code"] as? String
        let detail: String
        switch (message, code) {
        case let (message?, code?):
            detail = "\(message) (\(code))"
        case let (message?, nil):
            detail = message
        case let (nil, code?):
            detail = code
        default:
            detail = "Responses request failed (status: \(status))"
        }
        throw OpenAICompatibleProviderError.apiError(message: detail)
    }

    private nonisolated static func responsesText(from object: [String: Any]) -> String {
        if let text = object["output_text"] as? String { return text }
        guard let output = object["output"] as? [[String: Any]] else { return "" }
        return output
            .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
            .compactMap { responsesContentText(from: $0) }
            .joined()
    }

    /// 提取一个 Responses 内容块的文本。
    ///
    /// 两种块都可能出现：
    /// - `output_text`：正文，读 `text`；
    /// - `refusal`：拒答，读 `refusal`。
    ///
    /// 拒答块此前被忽略，于是一次**合法完成的拒答**变成空内容，AgentLoop
    /// 把它归类成通用的、不可恢复的 `emptyResponse`——用户看不到模型给出
    /// 的拒绝说明（与 Chat Completions 的 `message.refusal` 同类问题）。
    private nonisolated static func responsesContentText(from block: [String: Any]) -> String? {
        if let text = block["text"] as? String { return text }
        if let refusal = block["refusal"] as? String { return refusal }
        return nil
    }

    /// Normalize the usage shapes used by OpenAI, Anthropic-compatible
    /// gateways, Responses proxies, and common OpenAI-compatible gateways.
    private nonisolated func tokenCounts(from usage: [String: Any]?, anthropic: Bool) -> (
        input: Int?,
        output: Int?,
        cachedInput: Int?,
        cacheWrite: Int?,
        cacheTotal: Int?
    ) {
        guard let usage else {
            return (nil, nil, nil, nil, nil)
        }

        let input: Int?
        let output: Int?
        if anthropic {
            input = usage["input_tokens"] as? Int
                ?? usage["prompt_tokens"] as? Int
                ?? usage["input_token_count"] as? Int
            output = usage["output_tokens"] as? Int
                ?? usage["completion_tokens"] as? Int
                ?? usage["output_token_count"] as? Int
        } else {
            input = usage["prompt_tokens"] as? Int
                ?? usage["input_tokens"] as? Int
                ?? usage["prompt_token_count"] as? Int
                ?? usage["input_token_count"] as? Int
            output = usage["completion_tokens"] as? Int
                ?? usage["output_tokens"] as? Int
                ?? usage["candidates_token_count"] as? Int
                ?? usage["output_token_count"] as? Int
        }

        let cachedInput = anthropic
            ? AnthropicCompatibleProviderAdapter.cacheReadInputTokens(from: usage)
            : OpenAICompatibleProviderAdapter.cacheReadInputTokens(from: usage)
        let cacheWrite = anthropic
            ? AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(from: usage)
            : OpenAICompatibleProviderAdapter.cacheWriteInputTokens(from: usage)
        let cacheTotal = anthropic
            ? AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
                inputTokens: input,
                cachedInputTokens: cachedInput,
                cacheWriteInputTokens: cacheWrite
            )
            : input
        return (input, output, cachedInput, cacheWrite, cacheTotal)
    }
}

/// Responses 协议的响应提取结果。
///
/// 全部是纯值类型，因此可以从后台线程安全地带回主线程
/// （`[String: Any]` 不满足 `Sendable`）。
private struct ResponsesExtraction: Sendable {
    let text: String
    let responseID: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let cachedInputTokens: Int?
    let cacheWriteTokens: Int?
    let cacheTotalInputTokens: Int?
}

// MARK: - Tool schema adapter

private struct AdapterToolSchema: LLMToolSchemaProviding, @unchecked Sendable {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(_ schema: LLMFunctionSchema) {
        self.name = schema.name
        self.toolDescription = schema.description
        self.inputSchema = schema.parameters
    }
}

// MARK: - Streaming accumulator

final class StreamingAccumulator: @unchecked Sendable {
    private var content = ""
    private var reasoningContent = ""
    private var redactedThinking: [LLMRedactedThinkingBlock] = []
    private var toolCalls: [Int: ToolCall] = [:]
    private var toolCallOrder: [Int] = []
    private var inputTokens: Int?
    private var outputTokens: Int?
    private var cachedInputTokens: Int?
    private var cacheWriteInputTokens: Int?
    private var cacheTotalInputTokens: Int?
    private var responseID: String?
    private var rawStreamEvents: [String] = []
    private var stopReason: String?
    /// 累积的生成图片（图像生成模型的产物）。
    private var images: [MessageImage] = []
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

        if let v = chunk.inputTokens { self.inputTokens = v }
        if let v = chunk.outputTokens { self.outputTokens = v }
        if let v = chunk.cachedInputTokens { self.cachedInputTokens = v }
        if let v = chunk.cacheWriteInputTokens { self.cacheWriteInputTokens = v }
        if let v = chunk.cacheTotalInputTokens { self.cacheTotalInputTokens = v }
        if let v = chunk.responseID { self.responseID = v }
        if let v = chunk.stopReason {
            self.stopReason = v
            // OpenAI-compatible gateways may send finish_reason without a
            // trailing [DONE]; it is still an explicit protocol terminator.
            finished = true
        }
        if let rawEvent = chunk.rawEvent { rawStreamEvents.append(rawEvent) }

        // redacted thinking 是不透明块，整块到达，不做增量拼接。
        if let data = chunk.redactedThinkingData, !data.isEmpty {
            redactedThinking.append(LLMRedactedThinkingBlock(data: data))
        }
        // 整段 JSON 回退会在单个 chunk 里携带多块（#1167），逐块收集。
        if let blocks = chunk.redactedThinkingBlocks {
            for data in blocks where !data.isEmpty {
                redactedThinking.append(LLMRedactedThinkingBlock(data: data))
            }
        }

        // 思考增量
        //
        // - Important: 这里**只**带 `reasoningContent`，不带 `content`。
        //   思考增量与正文增量是两种不同的东西，把同一段文本同时塞进两个字段
        //   会让下游把它当成「正文」再写一遍：AgentLoop 的分派是
        //   `appendThinking(reasoning)` 后 `appendContent(content)`，于是同一个
        //   chunk 会走两趟，第二趟把流式阶段从 `.thinking` 翻成 `.generating`。
        //   思考模型（MiniMax M3 等默认开启思考）的每个思考 token 都会触发一次
        //   「正在思考…」→「正在生成回复…」的来回翻转，V1 的底部状态卡因此
        //   逐 token 抖动。GoProvider 走的就是「只带 reasoningContent」这条路。
        if chunk.eventType == .thinkingDelta, let piece = chunk.content {
            reasoningContent += piece
            await onChunk(LLMStreamChunk(reasoningContent: piece))
        }

        // 正文增量
        if chunk.eventType != .thinkingDelta, let piece = chunk.content, !piece.isEmpty {
            content += piece
            await onChunk(LLMStreamChunk(content: piece))
        }

        // 图片增量（图像生成模型的产物）
        if let chunkImages = chunk.images, !chunkImages.isEmpty {
            images.append(contentsOf: chunkImages)
            await onChunk(LLMStreamChunk(images: chunkImages))
        }

        // 工具调用增量
        if let calls = chunk.toolCalls, !calls.isEmpty {
            for call in calls {
                let index = chunk.toolCallIndex ?? nextIndex()
                upsertToolCall(index: index, call: call)
            }
        } else if let partial = chunk.partialJson, !partial.isEmpty {
            // Anthropic provides the content-block index on every tool delta.
            // Keep the fallback for gateways that omit it, but never retain a
            // stale index from a previous partial-json event.
            let index = chunk.toolCallIndex ?? toolCallOrder.last ?? 0
            upsertArguments(index: index, fragment: partial)
        }

        if chunk.isDone {
            finished = true
            return false
        }
        return true
    }

    func finish(model: String) async throws -> LLMResponse {
        if let failure { throw failure }
        guard finished else { throw VendorAPIError.incompleteStream }
        let finalCalls = toolCallOrder.compactMap { toolCalls[$0] }
        let rawStreamEventsJSON = try? String(
            data: JSONSerialization.data(withJSONObject: rawStreamEvents),
            encoding: .utf8
        )
        return LLMResponse(
            content: content,
            model: model,
            toolCalls: finalCalls.isEmpty ? nil : finalCalls.map {
                LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: reasoningContent.isEmpty ? nil : reasoningContent,
            redactedThinking: redactedThinking.isEmpty ? nil : redactedThinking,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            cachedInputTokenCount: cachedInputTokens,
            cacheWriteInputTokenCount: cacheWriteInputTokens,
            cacheTotalInputTokenCount: cacheTotalInputTokens,
            responseID: responseID,
            rawStreamEventsJSON: rawStreamEventsJSON,
            stopReason: stopReason,
            images: images.isEmpty ? nil : images
        )
    }

    func fail(_ error: Error) { failure = error }

    private func nextIndex() -> Int {
        toolCallOrder.last.map { $0 + 1 } ?? 0
    }

    private func upsertToolCall(index: Int, call: ToolCall) {
        if let existing = toolCalls[index] {
            toolCalls[index] = ToolCall(
                id: existing.id.isEmpty ? call.id : existing.id,
                name: existing.name.isEmpty ? call.name : existing.name,
                arguments: existing.arguments + call.arguments
            )
        } else {
            toolCalls[index] = call
            if !toolCallOrder.contains(index) { toolCallOrder.append(index) }
        }
    }

    private func upsertArguments(index: Int, fragment: String) {
        if var existing = toolCalls[index] {
            // OpenAI-compatible streams commonly emit the tool name first and
            // omit `function.arguments`; the parser represents that omission
            // as "{}". Do not prefix the real argument fragments with that
            // placeholder, otherwise the final JSON becomes invalid.
            let existingArguments = existing.arguments == "{}" ? "" : existing.arguments
            existing = ToolCall(id: existing.id, name: existing.name, arguments: existingArguments + fragment)
            toolCalls[index] = existing
        } else {
            toolCalls[index] = ToolCall(id: "", name: "", arguments: fragment)
            if !toolCallOrder.contains(index) { toolCallOrder.append(index) }
        }
    }
}
