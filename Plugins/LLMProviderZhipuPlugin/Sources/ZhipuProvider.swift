import Foundation
import LLMProviderKit
import LLMKit
import AgentToolKit
import HttpKit
import LumiCoreKit
import SuperLogKit

/// Zhipu AI (智谱 AI) API 供应商实现
///
/// Zhipu AI 提供了兼容 Anthropic 的 API 接口，但在流式响应结束时会返回 OpenAI 格式的 `data: [DONE]` 标记。
/// 因此需要同时兼容两种格式的解析。
public final class ZhipuProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🔴"
    public nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    public static let id = "zhipu"
    public static let displayName = String(localized: "Zhipu AI CodingPlan", bundle: .module)
    public static let shortName = "ZhiPu"
    public static let description = String(localized: "智谱 AI (GLM)", bundle: .module)

    public static let websiteURL: String? = "https://open.bigmodel.cn"

    /// 智谱开放平台 API Key 管理页（用于聊天内引导链接）
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"

    // MARK: - 配置相关

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_Zhipu"
    public static let defaultModel = "glm-4.7"

    public static let modelCatalog: [LumiCoreKit.LLMModelCatalogItem] = [
        .init(id: "glm-5.1", description: "GLM 5.1，智谱最新旗舰模型，推理和代码能力全面升级", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-5-turbo", description: "GLM 5 Turbo，高速推理版本，兼顾性能与速度", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-5", description: "GLM 5，智谱通用大模型，综合能力出色", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-4.7", description: "GLM 4.7，成熟稳定的通用语言模型", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-4.6", description: "GLM 4.6，性价比优秀的通用模型", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-4.5", description: "GLM 4.5，基础通用模型，适合日常对话", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "glm-4.5-air", description: "GLM 4.5 Air，轻量快速版本，响应速度更快", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - SuperLLMProvider

    public required override init() {
        super.init()
    }

    public var baseURL: String {
        "https://open.bigmodel.cn/api/anthropic/v1/messages"
    }

    public func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(Self.getApiKey(), forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    public func buildRequestBody(
        messages: [LumiCoreKit.ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        try RequestBuilder.buildBody(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
    }

    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        try ResponseParser.parse(data: data)
    }

    public func buildStreamingRequestBody(
        messages: [LumiCoreKit.ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        try RequestBuilder.buildStreamingBody(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
    }

    public func parseStreamChunk(data: Data) throws -> LumiCoreKit.StreamChunk? {
        StreamParser.parseChunk(data: data)
    }


    // MARK: - Transport

    public func streamChat(
        messages: [LumiCoreKit.ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (LumiCoreKit.StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> LumiCoreKit.ChatMessage {
        try await ZhipuChatTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    public func sendMessage(
        messages: [LumiCoreKit.ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> LumiCoreKit.ChatMessage {
        try await ZhipuChatTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    public func availabilityCheckStrategy(forModel modelId: String) -> LumiCoreKit.AvailabilityCheckStrategy {
        .chatPing()
    }

    public func applyGenerationOptions(config: LLMConfig, model: String, to body: inout [String: Any]) {
        AnthropicCompatibleGenerationOptionsApplier.apply(
            config: config,
            model: model,
            defaultMaxTokens: RequestBuilder.defaultMaxTokens,
            to: &body
        )
    }

    public func parseProviderHTTPError(data: Data?, statusCode: Int?) -> ProviderHTTPError? {
        ProviderHTTPErrorParser.parseAnthropicCompatible(data: data, statusCode: statusCode)
    }
}
