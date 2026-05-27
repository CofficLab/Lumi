import Foundation
import AgentToolKit
import LLMProviderKit
import LumiCoreKit

/// Feifeimiao API 供应商实现
///
/// Feifeimiao (api.feifeimiao.top) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class FeifeimiaoProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🐦"
    nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    static let id = "feifeimiao"
    static let displayName = String(localized: "Feifeimiao", table: "Feifeimiao")
    static let shortName = "FF"
    static let description = String(localized: "LLM API by feifeimiao", table: "Feifeimiao")

    static let websiteURL: String? = "https://api.feifeimiao.top"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Feifeimiao"
    static let defaultModel = "gpt-5.5"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", description: "GPT-5.5，OpenAI 最新旗舰模型，综合能力最强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4", description: "GPT-5.4，OpenAI 高性能通用模型", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-mini", description: "GPT-5.4 Mini，轻量高效版本，适合快速响应场景", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3", description: "GPT-5.3，通用对话模型，推理能力出色", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2", description: "GPT-5.2，稳定可靠的通用模型", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.feifeimiao.top/v1/chat/completions",
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

    // MARK: - Availability

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}
