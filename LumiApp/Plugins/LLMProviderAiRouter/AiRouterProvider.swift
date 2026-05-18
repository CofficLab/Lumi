import Foundation
import LLMProviderKit
import MagicKit

/// AiRouter API 供应商实现
///
/// AiRouter (airouter.org) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class AiRouterProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    static let id = "airouter"
    static let displayName = String(localized: "AiRouter", table: "AiRouter")
    static let description = String(localized: "LLM Router by airouter.org", table: "AiRouter")

    static let websiteURL: String? = "https://airouter.org"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_AiRouter"
    static let defaultModel = "gpt-5"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.1-codex-max", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2-codex", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-mini", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex-mini", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3-codex", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5-codex", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = false

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.airouter.org/v1/chat/completions",
            includeUsageInStreamOptions: true
        )
    )

    override init() {
        super.init()
    }

    var baseURL: String {
        adapter.configuration.baseURL
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
            messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt
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
            messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt
        )
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let kitChunk = try adapter.parseStreamChunk(data: data) else { return nil }
        return StreamChunk(kit: kitChunk)
    }
}
