import Foundation
import AgentToolKit
import LLMProviderKit

/// HappyCode API 供应商实现
///
/// HappyCode (happycode.vip) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class HappyCodeProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🎉"
    nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    static let id = "happycode"
    static let displayName = String(localized: "HappyCode", table: "HappyCode")
    static let shortName = "HC"
    static let description = String(localized: "AI API Gateway by HappyCode", table: "HappyCode")

    static let websiteURL: String? = "https://happycode.vip"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_HappyCode"
    static let defaultModel = "gpt-5.5"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", description: "GPT-5.5，OpenAI 最新旗舰模型，超强推理和多模态能力", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://happycode.vip/v1/chat/completions",
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

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        let result = try adapter.parseResponse(data: data)
        let kitToolCalls = result.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) }
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