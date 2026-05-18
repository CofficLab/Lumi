import Foundation
import LLMProviderKit
import MagicKit

// MARK: - OpenRouter Provider

/// OpenRouter 供应商实现
///
/// OpenRouter 是一个聚合多个 LLM 供应商的平台，API 兼容 OpenAI 格式。
/// 支持 Tool Calls 和流式响应。
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class OpenRouterProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🔵"

    // MARK: - Basic Info

    static let id = "openrouter"
    static let displayName = String(localized: "OpenRouter", table: "OpenRouter")
    static let description = String(localized: "Multi-Provider LLM Router", table: "OpenRouter")

    static let websiteURL: String? = "https://openrouter.ai"

    // MARK: - Configuration

    static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenRouter"
    static let defaultModel = "alibaba/qwen3.5-397b"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "alibaba/qwen3.5-397b", spec: .init(contextWindowSize: 131_072, supportsVision: false, supportsTools: true)),
        .init(id: "anthropic/claude-haiku-4-5-20251001", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-opus-4-5-20251101", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-sonnet-4-5-20250929", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "bytedance-seed/seedream-4.5", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "deepseek/deepseek-v3.1", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "google/gemma-3-27b-it:free", spec: .init(contextWindowSize: 131_072, supportsVision: true, supportsTools: true)),
        .init(id: "google/gemini-pro-2.5", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "meta-llama/llama-3.3-70b-instruct", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.1", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.5:free", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "nvidia/nemotron-3-super-120b-a12b:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-4o", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "openai/gpt-5", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-5-mini", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-oss-20b:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "qwen/qwen3.6-plus", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "stepfun/step-3.5-flash:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "z-ai/glm-4.5-air:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - Adapter

    /// OpenRouter 要求的额外请求头
    private static let openRouterHeaders: [String: String] = [
        "HTTP-Referer": "Lumi",
        "X-Title": "Lumi",
    ]

    private lazy var adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            additionalHeaders: Self.openRouterHeaders,
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: true,
            acceptsFunctionScopedToolCallID: true
        )
    )

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://openrouter.ai/api/v1/chat/completions"
    }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        let kitMessages = messages.map { LLMProviderKit.ChatMessage(app: $0) }
        let kitTools = tools?.map { SuperAgentToolBridge(tool: $0) }
        return try adapter.buildRequestBody(
            messages: kitMessages,
            model: model,
            tools: kitTools,
            systemPrompt: systemPrompt
        )
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        let result = try adapter.parseResponse(data: data)
        let kitToolCalls = result.toolCalls?.map { ToolCall(kit: $0) }
        return (result.content, kitToolCalls)
    }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        let kitMessages = messages.map { LLMProviderKit.ChatMessage(app: $0) }
        let kitTools = tools?.map { SuperAgentToolBridge(tool: $0) }
        return try adapter.buildStreamingRequestBody(
            messages: kitMessages,
            model: model,
            tools: kitTools,
            systemPrompt: systemPrompt
        )
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let kitChunk = try adapter.parseStreamChunk(data: data) else {
            return nil
        }
        return StreamChunk(kit: kitChunk)
    }
}
