import Foundation
import AgentToolKit
import LLMProviderKit
import LumiCoreKit

/// OpenAI API 供应商实现
///
/// 集成 OpenAI GPT 系列模型，支持 Tool Calls 和流式响应。
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class OpenAIProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "🟢"

    // MARK: - 基础信息

    static let id = "openai"
    static let displayName = String(localized: "OpenAI", table: "OpenAI")
    static let shortName = "OA"
    static let description = String(localized: "GPT by OpenAI", table: "OpenAI")

    static let websiteURL: String? = "https://openai.com"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenAI"
    static let defaultModel = "gpt-4o"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-4o", description: "GPT-4o，OpenAI 多模态旗舰模型，支持视觉和工具调用", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4o-mini", description: "GPT-4o Mini，轻量高效版本，适合快速响应", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4-turbo", description: "GPT-4 Turbo，高性能版本，支持更长上下文", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4", description: "GPT-4，经典旗舰模型，推理能力出色", spec: .init(contextWindowSize: 8_192, supportsVision: false, supportsTools: true)),
        .init(id: "gpt-3.5-turbo", description: "GPT-3.5 Turbo，经济实惠模型，适合轻量任务", spec: .init(contextWindowSize: 16_385, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
    )

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://api.openai.com/v1/chat/completions"
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

    // MARK: - Availability

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}
