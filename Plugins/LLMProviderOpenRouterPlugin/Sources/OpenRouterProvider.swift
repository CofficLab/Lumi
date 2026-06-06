import Foundation
import AgentToolKit
import LLMProviderKit
import HttpKit
import LLMKit
import LumiCoreKit
import SuperLogKit

// MARK: - OpenRouter Provider

/// OpenRouter 供应商实现
///
/// OpenRouter 是一个聚合多个 LLM 供应商的平台，API 兼容 OpenAI 格式。
/// 支持 Tool Calls 和流式响应。
/// 使用 LLMProviderKit 的 OpenAICompatibleProviderAdapter 处理请求构建和响应解析。
public final class OpenRouterProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🔵"

    // MARK: - Basic Info

    public static let id = "openrouter"
    public static let displayName = String(localized: "OpenRouter", bundle: .module)
    public static let shortName = "OR"
    public static let description = String(localized: "Multi-Provider LLM Router", bundle: .module)

    public static let websiteURL: String? = "https://openrouter.ai"

    // MARK: - Configuration

    public static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenRouter"
    public static let defaultModel = "alibaba/qwen3.5-397b"

    public static let modelCatalog: [LumiCoreKit.LLMModelCatalogItem] = [
        .init(id: "alibaba/qwen3.5-397b", description: "通义千问 3.5 397B，阿里云超大参数模型，综合能力强", spec: .init(contextWindowSize: 131_072, supportsVision: false, supportsTools: true)),
        .init(id: "anthropic/claude-haiku-4-5-20251001", description: "Claude 4.5 Haiku，Anthropic 最新轻量模型，响应极快", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-opus-4-5-20251101", description: "Claude 4.5 Opus，Anthropic 最新旗舰，深度推理能力顶尖", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-sonnet-4-5-20250929", description: "Claude 4.5 Sonnet，Anthropic 平衡型模型，智能与速度兼备", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "bytedance-seed/seedream-4.5", description: "Seedream 4.5，字节跳动多模态模型，支持视觉理解", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "deepseek/deepseek-v3.1", description: "DeepSeek V3.1，高性能推理模型，擅长逻辑和代码", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "google/gemma-3-27b-it:free", description: "Gemma 3 27B，Google 开源模型，免费可用", spec: .init(contextWindowSize: 131_072, supportsVision: true, supportsTools: true)),
        .init(id: "google/gemini-pro-2.5", description: "Gemini Pro 2.5，Google 旗舰模型，支持百万级上下文", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "meta-llama/llama-3.3-70b-instruct", description: "Llama 3.3 70B，Meta 开源大模型，性能均衡", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.1", description: "MiniMax M2.1，高性价比中文模型，擅长对话", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.5:free", description: "MiniMax M2.5，免费版本，适合轻量使用", spec: .init(contextWindowSize: 200_000, supportsVision: false, supportsTools: true)),
        .init(id: "nvidia/nemotron-3-super-120b-a12b:free", description: "Nemotron 3 Super 120B，NVIDIA 开源超大模型，免费可用", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-4o", description: "GPT-4o，OpenAI 多模态旗舰模型，支持视觉和工具", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "openai/gpt-5", description: "GPT-5，OpenAI 最新旗舰模型，综合能力最强", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-5-mini", description: "GPT-5 Mini，OpenAI 轻量模型，适合快速响应", spec: .init(contextWindowSize: 272_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-oss-20b:free", description: "GPT-OSS 20B，OpenAI 开源模型，免费可用", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "qwen/qwen3.6-plus", description: "通义千问 3.6 Plus，最新一代阿里云大模型，性能更强", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "stepfun/step-3.5-flash:free", description: "Step 3.5 Flash，阶跃星辰轻量模型，免费可用", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "z-ai/glm-4.5-air:free", description: "GLM 4.5 Air，智谱轻量模型，免费可用", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
    ]

    // MARK: - Adapter

    /// OpenRouter 要求的额外请求头
    private static let openRouterHeaders: [String: String] = [
        "HTTP-Referer": "Lumi",
        "X-Title": "Lumi",
    ]

    private lazy var adapter = OpenAICompatibleProviderAdapter(
        configuration: OpenAICompatibleProviderConfiguration(
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            additionalHeaders: Self.openRouterHeaders,
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: true,
            acceptsFunctionScopedToolCallID: true
        )
    )

    public required override init() {
        super.init()
    }

    public var baseURL: String {
        "https://openrouter.ai/api/v1/chat/completions"
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
        .chatPing()
    }
}
