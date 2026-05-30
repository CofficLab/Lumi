import Foundation
import AgentToolKit
import LLMProviderKit
import LumiCoreKit
import SuperLogKit

// MARK: - DeepSeek Provider

/// DeepSeek 供应商实现
///
/// DeepSeek API 兼容 OpenAI 格式，支持 Tool Calls 和流式响应。
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
public final class DeepSeekProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🟠"

    // MARK: - Basic Info

    public static let id = "deepseek"
    public static let displayName = String(localized: "DeepSeek", table: "DeepSeek")
    public static let shortName = "DS"
    public static let description = String(localized: "DeepSeek AI", table: "DeepSeek")

    public static let websiteURL: String? = "https://deepseek.com"

    // MARK: - Configuration

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"
    public static let defaultModel = "deepseek-chat"

    public static let modelCatalog: [LumiCoreKit.LLMModelCatalogItem] = [
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

    public required override init() {
        super.init()
    }

    public var baseURL: String {
        "https://api.deepseek.com/v1/chat/completions"
    }

    public func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    public func buildRequestBody(
        messages: [LumiCoreKit.ChatMessage],
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

    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        let result = try adapter.parseResponse(data: data)
        let kitToolCalls = result.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) }
        return (result.content, kitToolCalls)
    }

    public func buildStreamingRequestBody(
        messages: [LumiCoreKit.ChatMessage],
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

    public func parseStreamChunk(data: Data) throws -> LumiCoreKit.StreamChunk? {
        guard let kitChunk = try adapter.parseStreamChunk(data: data) else {
            return nil
        }
        return LumiCoreKit.StreamChunk(kit: kitChunk)
    }

    // MARK: - Availability

    public func availabilityCheckStrategy(forModel modelId: String) -> LumiCoreKit.AvailabilityCheckStrategy {
        .chatPing()
    }
}
