import Foundation
import os
import ProviderMessage
import ProviderNetwork
import KitSuperLog

/// 新版内建 LLM 供应商基类（KernelCore 生态，不依赖 KernelLumi）。
///
/// 每个供应商子类只需提供：
/// - `providerInfo`（模型列表、协议格式、API Key storage key 等元数据）；
/// - 对应协议的 adapter 配置（`openAIConfiguration` / `anthropicConfiguration`）。
///
/// 发送路径：
/// - 非流式 JSON（`complete(_:)`），按 `apiFormat` 路由到 OpenAI / Anthropic /
///   Responses 三套 adapter，复用 LLMKit 的请求构建与响应解析；
/// - 流式 SSE（`streamComplete(_:onChunk:)`），OpenAI / Anthropic 走
///   `buildStreamingRequestBody` + `parseStreamChunk`，Responses 协议回退非流式。
/// 两条路径均支持工具 schema 传递（`LLMRequest.tools`）与推理档位
/// （`LLMRequest.reasoningEffort`）。
@MainActor
open class VendorLLMProvider: SuperLLMProvider, @preconcurrency LLMProviding, LLMStreamingProviding, SuperLog {
    nonisolated public class var logger: Logger {
        Logger(subsystem: "com.coffic.lumi.provider-llm-vendors", category: "VendorLLMProvider")
    }
    nonisolated public class var emoji: String { "🔗" }
    nonisolated public class var verbose: Bool { false }

    public let providerInfo: LLMProviderInfo
    public let apiService: VendorAPIService

    /// OpenAI 兼容协议适配器配置（子类覆盖）。
    open var openAIConfiguration: OpenAICompatibleProviderConfiguration? { nil }

    /// Anthropic 兼容协议适配器配置（子类覆盖）。
    open var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? { nil }

    public init(
        info: LLMProviderInfo,
        apiService: VendorAPIService = VendorAPIService()
    ) {
        self.providerInfo = info
        self.apiService = apiService
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    ///
    /// 所有通过此初始化创建的供应商，其网络请求都会经过 `NetworkProviding`，
    /// 从而可以被 `HTTPExchangeStore` 记录。
    public convenience init(
        info: LLMProviderInfo,
        networkProvider: (any NetworkProviding)?
    ) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(info: info, apiService: apiService)
    }

    public var providerID: String { providerInfo.id }

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
            // Responses 协议暂无独立流式路径，回退非流式（功能可用，体验降级）。
            return try await complete(request)
        }
    }

    // MARK: - API Key

    public func hasApiKey() -> Bool {
        VendorAPIKeyTools.has(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func getApiKey() -> String {
        VendorAPIKeyTools.get(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func setApiKey(_ apiKey: String) {
        VendorAPIKeyTools.set(apiKey, storageKey: providerInfo.apiKeyStorageKey)
    }

    public func removeApiKey() {
        VendorAPIKeyTools.remove(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func resolveAPIKey() throws -> String {
        do {
            return try VendorAPIKeyTools.resolve(
                storageKey: providerInfo.apiKeyStorageKey,
                displayName: providerInfo.displayName
            )
        } catch {
            Self.logger.error("\(Self.t)\(self.providerInfo.displayName, privacy: .public) resolveAPIKey failed\(self.r(error.localizedDescription))")
            throw error
        }
    }

    // MARK: - OpenAI (non-streaming)

    private func sendOpenAI(_ request: LLMRequest) async throws -> LLMResponse {
        guard let configuration = openAIConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 OpenAI 端点")
        }
        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let (tools, reverseMap) = toolSchemas(from: request.tools)
        let model = request.model ?? providerInfo.defaultModel
        var body = try adapter.buildRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: model,
            tools: tools,
            systemPrompt: ""
        )
        OpenAICompatibleGenerationOptionsApplier.apply(
            config: makeConfig(model: model, request: request),
            model: model,
            to: &body
        )
        nonisolated(unsafe) let finalBody = body
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            body: finalBody
        )
        let parsed = try adapter.parseResponse(data: data, reverseMap: reverseMap)
        return LLMResponse(
            content: parsed.content,
            model: model,
            toolCalls: parsed.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            reasoningContent: parsed.reasoningContent
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
        var body = try adapter.buildRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: model,
            tools: tools,
            systemPrompt: ""
        )
        AnthropicCompatibleGenerationOptionsApplier.apply(
            config: makeConfig(model: model, request: request),
            model: model,
            defaultMaxTokens: configuration.defaultMaxTokens,
            to: &body
        )
        nonisolated(unsafe) let finalBody = body
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            body: finalBody
        )
        let parsed = try adapter.parseResponse(data: data, reverseMap: reverseMap)
        return LLMResponse(
            content: parsed.content,
            model: model,
            toolCalls: parsed.toolCalls?.map { MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
        )
    }

    // MARK: - Responses（OpenAI Responses 协议）

    private func sendResponses(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        var input: [[String: Any]] = []
        for message in VendorMessageBridging.chatMessages(from: request.messages) {
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
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let text = Self.responsesText(from: object)
        return LLMResponse(content: text, model: model)
    }

    /// Responses 协议端点；默认 OpenAI 官方，子类可覆盖。
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
        // body 是纯 JSON 字典（Sendable 值），在 MainActor 上构造后交给非隔离的
        // SSE 传输方法；`nonisolated(unsafe)` 避免跨 actor 边界的发送风险误报。
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: model,
            tools: tools,
            systemPrompt: "",
            config: makeConfig(model: model, request: request)
        )

        let accumulator = StreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
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
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: model,
            tools: tools,
            systemPrompt: "",
            config: makeConfig(model: model, request: request)
        )

        let accumulator = StreamingAccumulator()
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
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
        return try await accumulator.finish(model: model)
    }

    // MARK: - Helpers

    /// 把 `LLMFunctionSchema` 适配为 adapter 需要的 `LLMToolSchemaProviding`，
    /// 同时返回工具名 sanitize 的反查表（sanitized → 原始注册名）。
    private func toolSchemas(from schemas: [LLMFunctionSchema]?)
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
            reasoningEffort: normalizedReasoningEffort(request.reasoningEffort)
        )
    }

    private func normalizedReasoningEffort(_ value: String?) -> String? {
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

    private static func responsesText(from object: [String: Any]) -> String {
        if let text = object["output_text"] as? String { return text }
        guard let output = object["output"] as? [[String: Any]] else { return "" }
        return output
            .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["text"] as? String }
            .joined()
    }
}

// MARK: - Tool schema adapter

/// `LLMFunctionSchema` → `LLMToolSchemaProviding` 的轻量适配。
private struct AdapterToolSchema: LLMToolSchemaProviding {
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

/// 流式增量累积器：把逐 chunk 的文本/思考/工具调用/用量累积为完整响应。
///
/// 跨 `onEvent` 闭包持有可变状态，故用 `@unchecked Sendable` class 包装；
/// 所有读写都发生在 `consume` / `finish` / `fail` 的串行 async 上下文中。
private final class StreamingAccumulator: @unchecked Sendable {
    private var content = ""
    private var reasoningContent = ""
    private var toolCalls: [Int: ToolCall] = [:]
    private var toolCallOrder: [Int] = []
    private var pendingPartialIndex: Int?
    private var inputTokens: Int?
    private var outputTokens: Int?
    private var cachedInputTokens: Int?
    private var stopReason: String?
    private var finished = false
    private var failure: Error?

    /// 消费一个解析后的 chunk；返回 `true` 继续读取，`false` 提前终止。
    func consume(
        _ chunk: StreamChunk,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async -> Bool {
        if failure != nil {
            return false
        }

        // 错误 chunk：终止流并抛出。
        if let error = chunk.error {
            failure = VendorAPIError.requestFailed(error)
            return false
        }

        if let inputTokens = chunk.inputTokens { self.inputTokens = inputTokens }
        if let outputTokens = chunk.outputTokens { self.outputTokens = outputTokens }
        if let cachedInputTokens = chunk.cachedInputTokens { self.cachedInputTokens = cachedInputTokens }
        if let stopReason = chunk.stopReason { self.stopReason = stopReason }

        // 思考增量
        if chunk.eventType == .thinkingDelta, let piece = chunk.content {
            reasoningContent += piece
            await onChunk(LLMStreamChunk(content: piece, isThinking: true))
        }

        // 正文增量
        if chunk.eventType != .thinkingDelta, let piece = chunk.content, !piece.isEmpty {
            content += piece
            await onChunk(LLMStreamChunk(content: piece, isThinking: false))
        }

        // 工具调用增量：按 index 累积 id/name/arguments 分片。
        if let calls = chunk.toolCalls, !calls.isEmpty {
            for call in calls {
                let index = chunk.toolCallIndex ?? nextIndex()
                upsertToolCall(index: index, call: call)
            }
        } else if let partial = chunk.partialJson, !partial.isEmpty {
            let index = chunk.toolCallIndex ?? pendingPartialIndex ?? toolCallOrder.last ?? 0
            pendingPartialIndex = index
            upsertArguments(index: index, fragment: partial)
        }

        if chunk.isDone {
            finished = true
            return false
        }
        return true
    }

    /// 流结束：返回完整响应（无内容时抛空响应错误）。
    func finish(model: String) async throws -> LLMResponse {
        if let failure {
            throw failure
        }
        let finalCalls = toolCallOrder.compactMap { toolCalls[$0] }
        return LLMResponse(
            content: content,
            model: model,
            toolCalls: finalCalls.isEmpty ? nil : finalCalls.map {
                MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: reasoningContent.isEmpty ? nil : reasoningContent,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            cachedInputTokenCount: cachedInputTokens,
            stopReason: stopReason
        )
    }

    func fail(_ error: Error) {
        failure = error
    }

    // MARK: - Private

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
            if !toolCallOrder.contains(index) {
                toolCallOrder.append(index)
            }
        }
    }

    private func upsertArguments(index: Int, fragment: String) {
        if var existing = toolCalls[index] {
            // The initial tool-call chunk may contain only id/name and use
            // "{}" as a placeholder for missing arguments. Replace that
            // placeholder before appending subsequent JSON fragments.
            let existingArguments = existing.arguments == "{}" ? "" : existing.arguments
            existing = ToolCall(
                id: existing.id,
                name: existing.name,
                arguments: existingArguments + fragment
            )
            toolCalls[index] = existing
        } else {
            toolCalls[index] = ToolCall(id: "", name: "", arguments: fragment)
            if !toolCallOrder.contains(index) {
                toolCallOrder.append(index)
            }
        }
    }
}
