import Foundation
import LLMProviderKit
import MagicKit

/// Xiaomi AI 供应商实现
///
/// Xiaomi AI (token-plan-cn.xiaomimimo.com) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class XiaomiProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "📱"
    nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    static let id = "xiaomi"
    static let displayName = String(localized: "Xiaomi", table: "Xiaomi")
    static let description = String(localized: "Xiaomi AI Models", table: "Xiaomi")

    static let websiteURL: String? = "https://xiaomi.com"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Xiaomi"
    static let defaultModel = "mimo-v2.5-pro"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "mimo-v2.5-pro", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2.5", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-pro", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-omni", spec: .init(contextWindowSize: 256_000, supportsVision: true, supportsTools: true)),
        .init(id: "mimo-v2.5-tts", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voiceclone", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voicedesign", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2-tts", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
    ]

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://token-plan-cn.xiaomimimo.com/v1/chat/completions",
            includesReasoningContentInMessages: true
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

    func parseResponseWithMetadata(data: Data) throws -> LLMProviderResponse {
        let result = try adapter.parseResponse(data: data)
        let toolCalls = result.toolCalls?.map { ToolCall(kit: $0) }
        return LLMProviderResponse(
            content: result.content,
            toolCalls: toolCalls,
            thinkingContent: result.reasoningContent
        )
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
