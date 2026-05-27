import Foundation
import AgentToolKit
import LLMProviderKit

/// MegaLLM API 供应商实现
///
/// MegaLLM (ai.megallm.io) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class MegaLLMProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🚀"
    nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    static let id = "megallm"
    static let displayName = String(localized: "MegaLLM", table: "MegaLLM")
    static let shortName = "ML"
    static let description = String(localized: "MegaLLM AI", table: "MegaLLM")

    static let websiteURL: String? = "https://megallm.com"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_MegaLLM"
    static let defaultModel = "gpt-5-mini"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "alibaba-qwen3.5-397b", description: "通义千问 3.5 397B，阿里云超大参数模型，综合能力强", spec: .init(contextWindowSize: 131_072, supportsVision: false, supportsTools: true)),
        .init(id: "claude-haiku-4-5-20251001", description: "Claude 4.5 Haiku，Anthropic 最新轻量模型，响应极快", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "claude-opus-4-5-20251101", description: "Claude 4.5 Opus，Anthropic 最新旗舰，深度推理能力顶尖", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "claude-opus-4-6", description: "Claude 4.6 Opus，最强推理模型，适合高难度任务", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "claude-sonnet-4-5-20250929", description: "Claude 4.5 Sonnet，Anthropic 平衡型模型，智能与速度兼备", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "claude-sonnet-4-6", description: "Claude 4.6 Sonnet，最新平衡型模型，性能进一步提升", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "deepseek-ai/deepseek-v3.1", description: "DeepSeek V3.1，高性能推理模型，擅长逻辑和代码", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "grok-4.1-fast-reasoning", description: "Grok 4.1 Fast Reasoning，xAI 推理模型，速度快推理强", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5-mini", description: "GPT-5 Mini，OpenAI 轻量模型，适合快速响应", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-5.3-codex", description: "GPT-5.3 Codex，OpenAI 编程模型，擅长代码生成", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "llama3.3-70b-instruct", description: "Llama 3.3 70B，Meta 开源大模型，性能均衡", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimaxai/minimax-m2.1", description: "MiniMax M2.1，高性价比中文模型，擅长对话", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "newclaude-opus-4-6", description: "New Claude 4.6 Opus，优化版旗舰模型，推理能力更强", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
    ]

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://ai.megallm.io/v1/chat/completions"
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
