import Foundation
import AgentToolKit
import LLMProviderKit
import HttpKit
import LLMKit
import LumiCoreKit
import SuperLogKit

/// Xiaomi AI 供应商实现
///
/// Xiaomi AI (token-plan-cn.xiaomimimo.com) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
public final class XiaomiProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    public nonisolated static let emoji = "📱"
    public nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    public static let id = "xiaomi"
    public static let displayName = String(localized: "Xiaomi", bundle: .module)
    public static let shortName = "XM"
    public static let description = String(localized: "Xiaomi AI Models", bundle: .module)

    public static let websiteURL: String? = "https://platform.xiaomimimo.com/token-plan"

    // MARK: - 配置相关

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_Xiaomi"
    public static let defaultModel = "mimo-v2.5-pro"

    public static let modelCatalog: [LumiCoreKit.LLMModelCatalogItem] = [
        .init(id: "mimo-v2.5-pro", description: "MiMo V2.5 Pro，小米旗舰语言模型，支持百万级上下文", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2.5", description: "MiMo V2.5，小米通用语言模型，综合能力强", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-pro", description: "MiMo V2 Pro，小米专业版模型，适合复杂任务", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-omni", description: "MiMo V2 Omni，小米多模态模型，支持视觉理解", spec: .init(contextWindowSize: 256_000, supportsVision: true, supportsTools: true)),
        .init(id: "mimo-v2.5-tts", description: "MiMo V2.5 TTS，小米语音合成模型", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false, supportsTTS: true)),
        .init(id: "mimo-v2.5-tts-voiceclone", description: "MiMo V2.5 TTS VoiceClone，支持声音克隆的语音合成", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false, supportsTTS: true)),
        .init(id: "mimo-v2.5-tts-voicedesign", description: "MiMo V2.5 TTS VoiceDesign，支持自定义音色设计", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false, supportsTTS: true)),
        .init(id: "mimo-v2-tts", description: "MiMo V2 TTS，小米基础语音合成模型", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false, supportsTTS: true)),
    ]

    // MARK: - Adapter

    private let adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://token-plan-cn.xiaomimimo.com/v1/chat/completions",
            includesReasoningContentInMessages: true
        )
    )

    public required override init() {
        super.init()
    }

    public var baseURL: String {
        adapter.configuration.baseURL
    }

    public func buildRequest(url: URL) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: Self.getApiKey())
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

    public func parseResponseWithMetadata(data: Data) throws -> LumiCoreKit.LLMProviderResponse {
        let result = try adapter.parseResponse(data: data)
        let toolCalls = result.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) }
        return LumiCoreKit.LLMProviderResponse(
            content: result.content,
            toolCalls: toolCalls,
            thinkingContent: result.reasoningContent
        )
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


    // MARK: - Transport

    public func streamChat(
        messages: [LumiCoreKit.ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (LumiCoreKit.StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> LumiCoreKit.ChatMessage {
        try await RemoteLLMProviderTransport.streamChat(
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
        try await RemoteLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    // MARK: - Availability

    public func availabilityCheckStrategy(forModel modelId: String) -> LumiCoreKit.AvailabilityCheckStrategy {
        // TTS 模型不支持对话 API，仅验证 API Key 即可
        if Self.modelCapabilities[modelId]?.supportsTTS == true {
            return .apiKeyOnly
        }
        // 对话模型使用标准 chat ping
        return .chatPing()
    }
}
