import Foundation
import os

/// LLM 供应商基类（零项目依赖，纯系统框架实现）。
///
/// 子类只需提供：
/// - `providerInfo`（模型列表、协议格式、API Key storage key）
/// - `openAIConfiguration` 或 `anthropicConfiguration`（对应协议的端点配置）
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
        var body = try adapter.buildRequestBody(
            messages: request.messages,
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
            toolCalls: parsed.toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
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
            messages: request.messages,
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
            toolCalls: parsed.toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
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
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let text = Self.responsesText(from: object)
        return LLMResponse(content: text, model: model)
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
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: request.messages,
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
            messages: request.messages,
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
            reasoningEffort: normalizedReasoningEffort(request.reasoningEffort)
        )
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
        if let v = chunk.stopReason { self.stopReason = v }
        if let rawEvent = chunk.rawEvent { rawStreamEvents.append(rawEvent) }

        // 思考增量
        if chunk.eventType == .thinkingDelta, let piece = chunk.content {
            reasoningContent += piece
            await onChunk(LLMStreamChunk(content: piece, reasoningContent: piece))
        }

        // 正文增量
        if chunk.eventType != .thinkingDelta, let piece = chunk.content, !piece.isEmpty {
            content += piece
            await onChunk(LLMStreamChunk(content: piece))
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
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            cachedInputTokenCount: cachedInputTokens,
            cacheWriteInputTokenCount: cacheWriteInputTokens,
            cacheTotalInputTokenCount: cacheTotalInputTokens,
            responseID: responseID,
            rawStreamEventsJSON: rawStreamEventsJSON,
            stopReason: stopReason
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
