import KitLLM
import Foundation
import os
import ProviderLLMManager

/// OpenCode Go 供应商（Go 系列模型网关）。
///
/// 同一网关下按模型走三种协议（Responses / OpenAI / Anthropic），
/// 端点路径不同（`/responses`、`/chat/completions`、`/messages`），因此
/// 覆盖 `complete(_:)` 和 `streamComplete` 按模型路由，不复用基类的单一协议路径。
@MainActor
public final class GoProvider: VendorLLMProvider {
    // 基类已声明 emoji/logger/verbose；子类不应跨模块重定义 static let。
    // 本类自定义 emoji 通过扩展在文件末尾提供。

    /// 包装基类 `resolveAPIKey()`，在抛出前记录 error 日志。
    private func resolvedAPIKey() throws -> String {
        do {
            return try resolveAPIKey()
        } catch {
            Self.logger.error("resolveAPIKey failed\(error.localizedDescription)")
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
        "hy3": .openAI,
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
                    LLMModelInfo(id: "grok-4.5", displayName: "Grok 4.5"),
                    LLMModelInfo(id: "gpt-5.6-luna", displayName: "GPT 5.6 Luna"),
                    LLMModelInfo(id: "glm-5.3", displayName: "GLM-5.3"),
                    LLMModelInfo(id: "glm-5.2", displayName: "GLM-5.2"),
                    LLMModelInfo(id: "glm-5.1", displayName: "GLM-5.1"),
                    LLMModelInfo(id: "kimi-k3", displayName: "Kimi K3"),
                    LLMModelInfo(id: "kimi-k2.7-code", displayName: "Kimi K2.7 Code"),
                    LLMModelInfo(id: "kimi-k2.6", displayName: "Kimi K2.6"),
                    LLMModelInfo(id: "mimo-v2.5", displayName: "MiMo-V2.5"),
                    LLMModelInfo(id: "mimo-v2.5-pro", displayName: "MiMo-V2.5-Pro"),
                    LLMModelInfo(id: "deepseek-v4-pro", displayName: "DeepSeek V4 Pro"),
                    LLMModelInfo(id: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "hy3", displayName: "Hy3"),
                    LLMModelInfo(id: "minimax-m3", displayName: "MiniMax M3"),
                    LLMModelInfo(id: "minimax-m2.7", displayName: "MiniMax M2.7"),
                    LLMModelInfo(id: "minimax-m2.5", displayName: "MiniMax M2.5"),
                    LLMModelInfo(id: "qwen3.8-max", displayName: "Qwen3.8 Max"),
                    LLMModelInfo(id: "qwen3.7-max", displayName: "Qwen3.7 Max"),
                    LLMModelInfo(id: "qwen3.7-plus", displayName: "Qwen3.7 Plus"),
                    LLMModelInfo(id: "qwen3.6-plus", displayName: "Qwen3.6 Plus"),
                ],
                websiteURL: URL(string: "https://opencode.ai/docs/zh-cn/go/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_OpenCodeGo"
            ),
            apiService: apiService
        )
    }

    // MARK: - 按模型路由协议

    public override func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        guard let kind = Self.kinds[model] else {
            Self.logger.error("Unknown model: \(model, privacy: .public)")
            throw VendorAPIError.requestFailed("OpenCode Go 未知模型：\(model)")
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

    public override func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        guard let kind = Self.kinds[model] else {
            Self.logger.error("Unknown model: \(model, privacy: .public)")
            throw VendorAPIError.requestFailed("OpenCode Go 未知模型：\(model)")
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
        if anthropic {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
            let body = try adapter.buildRequestBody(
                messages: request.messages,
                model: model,
                tools: nil,
                systemPrompt: ""
            )
            let data = try await apiService.sendChatRequest(
                request: adapter.buildRequest(url: url, apiKey: apiKey),
                body: body
            )
            let parsed = try adapter.parseResponse(data: data)
            return LLMResponse(content: parsed.content, model: model)
        }

        let adapter = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
        let body = try adapter.buildRequestBody(
            messages: request.messages,
            model: model,
            tools: nil,
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: url, apiKey: apiKey),
            body: body
        )
        let parsed = try adapter.parseResponse(data: data)
        return LLMResponse(content: parsed.content, model: model)
    }

    // MARK: - OpenAI / Anthropic (streaming)

    private func streamChat(
        _ request: LLMRequest,
        model: String,
        apiKey: String,
        anthropic: Bool,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        if anthropic {
            let adapter = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
            nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
                messages: request.messages,
                model: model,
                tools: nil,
                systemPrompt: "",
                config: LLMConfig(model: model, providerId: providerInfo.id)
            )
            nonisolated(unsafe) var content = ""
            try await apiService.sendStreamingChatRequest(
                request: adapter.buildRequest(url: try endpointURL("\(Self.base)/messages"), apiKey: apiKey),
                body: body
            ) { data in
                do {
                    guard let chunk = try adapter.parseStreamChunk(data: data) else { return true }
                    if chunk.eventType == .thinkingDelta, let piece = chunk.content {
                        await onChunk(LLMStreamChunk(reasoningContent: piece))
                    } else if let piece = chunk.content, !piece.isEmpty {
                        content += piece
                        await onChunk(LLMStreamChunk(content: piece))
                    }
                    if chunk.isDone { return false }
                    return true
                } catch {
                    return false
                }
            }
            return LLMResponse(content: content, model: model)
        }

        let adapter = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: Self.base))
        nonisolated(unsafe) let body = try adapter.buildStreamingRequestBody(
            messages: request.messages,
            model: model,
            tools: nil,
            systemPrompt: "",
            config: LLMConfig(model: model, providerId: providerInfo.id)
        )
        nonisolated(unsafe) var content = ""
        try await apiService.sendStreamingChatRequest(
            request: adapter.buildRequest(url: try endpointURL("\(Self.base)/chat/completions"), apiKey: apiKey),
            body: body
        ) { data in
            do {
                guard let chunk = try adapter.parseStreamChunk(data: data) else { return true }
                if chunk.eventType == .thinkingDelta, let piece = chunk.content {
                    await onChunk(LLMStreamChunk(reasoningContent: piece))
                } else if let piece = chunk.content, !piece.isEmpty {
                    content += piece
                    await onChunk(LLMStreamChunk(content: piece))
                }
                if chunk.isDone { return false }
                return true
            } catch {
                return false
            }
        }
        return LLMResponse(content: content, model: model)
    }

    // MARK: - Responses

    private func sendResponses(
        _ request: LLMRequest,
        model: String,
        apiKey: String
    ) async throws -> LLMResponse {
        var input: [[String: Any]] = []
        for message in request.messages {
            input.append(["role": message.role.rawValue, "content": message.content])
        }
        let body: [String: Any] = ["model": model, "input": input]

        var httpRequest = URLRequest(url: try endpointURL("\(Self.base)/responses"))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await apiService.sendJSON(request: httpRequest, body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return LLMResponse(content: Self.responsesText(from: object), model: model)
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
