import Foundation
import AgentToolKit
import LLMProviderKit

/// FlyMux API 供应商实现
///
/// FlyMux (api.flymux.com) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class FlyMuxProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🕊️"
    nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    static let id = "flymux"
    static let displayName = String(localized: "FlyMux", table: "FlyMux")
    static let shortName = "FMX"
    static let description = String(localized: "AI API Gateway by flymux.com", table: "FlyMux")

    static let websiteURL: String? = "https://flymux.com"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_FlyMux"
    static let defaultModel = "gpt-5.1-codex"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.4", description: "GPT-5.4，OpenAI 最新通用模型，综合性能优秀", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-mini", description: "GPT-5.4 Mini，轻量高效版本，速度快成本低", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-openai-compact", description: "GPT-5.4 Compact，OpenAI 紧凑版模型，适合资源受限场景", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3", description: "GPT-5.3，通用对话模型，推理能力出色", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3-codex", description: "GPT-5.3 Codex，编程专用模型，擅长代码生成", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2", description: "GPT-5.2，新一代通用模型，推理和创作能力出色", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2-codex", description: "GPT-5.2 Codex，新一代编程模型，代码能力更强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1", description: "GPT-5.1，通用对话模型，推理能力增强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex", description: "GPT-5.1 Codex，编程模型，代码理解和生成能力优秀", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex-max", description: "GPT-5.1 Codex Max，最强编程模型，适合复杂代码任务", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex-mini", description: "GPT-5.1 Codex Mini，轻量编程模型，性价比高", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.flymux.com/v1/chat/completions",
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
