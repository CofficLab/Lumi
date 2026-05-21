import Foundation
import LLMProviderKit

// MARK: - DeepSeek Provider

/// DeepSeek 供应商实现
///
/// DeepSeek API 兼容 OpenAI 格式，支持 Tool Calls 和流式响应。
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class DeepSeekProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🟠"

    // MARK: - Basic Info

    static let id = "deepseek"
    static let displayName = String(localized: "DeepSeek", table: "DeepSeek")
    static let description = String(localized: "DeepSeek AI", table: "DeepSeek")

    static let websiteURL: String? = "https://deepseek.com"

    // MARK: - Configuration

    static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"
    static let defaultModel = "deepseek-chat"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "deepseek-chat", description: "DeepSeek Chat，通用对话模型，擅长中文理解和推理", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "deepseek-coder", description: "DeepSeek Coder，专业编程模型，擅长代码生成和调试", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.deepseek.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
    )

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://api.deepseek.com/v1/chat/completions"
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
