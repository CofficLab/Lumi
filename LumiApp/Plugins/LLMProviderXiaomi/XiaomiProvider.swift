import Foundation
import AgentToolKit
import LLMProviderKit

/// Xiaomi AI 供应商实现
///
/// Xiaomi AI (token-plan-cn.xiaomimimo.com) 完全兼容 OpenAI 格式
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
final class XiaomiProvider: NSObject, SuperLLMProvider, @unchecked Sendable {
    nonisolated static let emoji = "📱"
    nonisolated static let verbose: Bool = true

    // MARK: - 基础信息

    static let id = "xiaomi"
    static let displayName = String(localized: "Xiaomi", table: "Xiaomi")
    static let shortName = "XM"
    static let description = String(localized: "Xiaomi AI Models", table: "Xiaomi")

    static let websiteURL: String? = "https://xiaomi.com"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Xiaomi"
    static let defaultModel = "mimo-v2.5-pro"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "mimo-v2.5-pro", description: "MiMo V2.5 Pro，小米旗舰语言模型，支持百万级上下文", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2.5", description: "MiMo V2.5，小米通用语言模型，综合能力强", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-pro", description: "MiMo V2 Pro，小米专业版模型，适合复杂任务", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-omni", description: "MiMo V2 Omni，小米多模态模型，支持视觉理解", spec: .init(contextWindowSize: 256_000, supportsVision: true, supportsTools: true)),
        .init(id: "mimo-v2.5-tts", description: "MiMo V2.5 TTS，小米语音合成模型", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voiceclone", description: "MiMo V2.5 TTS VoiceClone，支持声音克隆的语音合成", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voicedesign", description: "MiMo V2.5 TTS VoiceDesign，支持自定义音色设计", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2-tts", description: "MiMo V2 TTS，小米基础语音合成模型", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
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

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        let result = try adapter.parseResponse(data: data)
        let kitToolCalls = result.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) }
        return (result.content, kitToolCalls)
    }

    func parseResponseWithMetadata(data: Data) throws -> LLMProviderResponse {
        let result = try adapter.parseResponse(data: data)
        let toolCalls = result.toolCalls?.map { AgentToolKit.ToolCall(kit: $0) }
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
