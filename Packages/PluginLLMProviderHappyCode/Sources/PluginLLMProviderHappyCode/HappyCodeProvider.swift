import Foundation
import AgentToolKit
import LLMProviderKit
import LumiCoreKit
import SuperLogKit

/// HappyCode API 供应商实现
///
/// HappyCode (happycode.vip) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
public final class HappyCodeProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    public nonisolated static let emoji = "🎉"
    public nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    public static let id = "happycode"
    public static let displayName = String(localized: "HappyCode", table: "HappyCode")
    public static let shortName = "HC"
    public static let description = String(localized: "AI API Gateway by HappyCode", table: "HappyCode")

    public static let websiteURL: String? = "https://happycode.vip"

    // MARK: - 配置相关

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_HappyCode"
    public static let defaultModel = "gpt-5.5"

    public static let modelCatalog: [LumiCoreKit.LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", description: "GPT-5.5，OpenAI 最新旗舰模型，超强推理和多模态能力", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
    ]

    // MARK: - 启用状态配置

    public static let isEnabled = true

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://happycode.vip/v1/chat/completions",
            includeUsageInStreamOptions: true
        )
    )

    public required override init() {
        super.init()
    }

    public var baseURL: String {
        adapter.configuration.baseURL
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
            messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt
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
            messages: kitMessages, model: model, tools: kitTools, systemPrompt: systemPrompt
        )
    }

    public func parseStreamChunk(data: Data) throws -> LumiCoreKit.StreamChunk? {
        guard let kitChunk = try adapter.parseStreamChunk(data: data) else { return nil }
        return LumiCoreKit.StreamChunk(kit: kitChunk)
    }

    // MARK: - Availability

    public func availabilityCheckStrategy(forModel modelId: String) -> LumiCoreKit.AvailabilityCheckStrategy {
        .chatPing()
    }
}