import Foundation
import ToolKit
import LLMProviderKit

/// HyperAPI 供应商实现
///
/// HyperAPI (hyperapi.cc) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class HyperAPIProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "⚡"
    nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    static let id = "hyperapi"
    static let displayName = String(localized: "HyperAPI", table: "HyperAPI")
    static let description = String(localized: "LLM Router by hyperapi.cc", table: "HyperAPI")

    static let websiteURL: String? = "https://hyperapi.cc"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_HyperAPI"
    static let defaultModel = "gpt-5"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.1-codex-max", description: "GPT-5.1 Codex Max，最强编程模型，适合复杂代码任务", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2-codex", description: "GPT-5.2 Codex，新一代编程模型，代码能力更强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4-mini", description: "GPT-5.4 Mini，轻量高效模型，速度快成本低", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5", description: "GPT-5，OpenAI 基础旗舰模型，综合能力强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex-mini", description: "GPT-5.1 Codex Mini，轻量编程模型，性价比高", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.2", description: "GPT-5.2，新一代通用模型，推理和创作能力出色", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3-codex", description: "GPT-5.3 Codex，编程专用模型，擅长代码生成", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.4", description: "GPT-5.4，最新通用模型，综合性能优秀", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5-codex", description: "GPT-5 Codex，基础编程模型，适合日常编码", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1", description: "GPT-5.1，通用对话模型，推理能力增强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.1-codex", description: "GPT-5.1 Codex，编程模型，代码理解和生成能力优秀", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://hyperapi.cc/v1/chat/completions",
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
        let kitToolCalls = result.toolCalls?.map { ToolKit.ToolCall(kit: $0) }
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
