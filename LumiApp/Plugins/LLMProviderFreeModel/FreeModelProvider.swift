import Foundation
import LLMProviderKit
import MagicKit

/// FreeModel API 供应商实现
///
/// FreeModel (api.freemodel.dev) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class FreeModelProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "⚡"
    nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    static let id = "freemodel"
    static let displayName = String(localized: "FreeModel", table: "FreeModel")
    static let description = String(localized: "Free LLM Gateway by freemodel.dev", table: "FreeModel")

    static let websiteURL: String? = "https://freemodel.dev"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_FreeModel"
    static let defaultModel = "gpt-5.4"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-mini", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3-codex", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.freemodel.dev/v1/chat/completions",
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
