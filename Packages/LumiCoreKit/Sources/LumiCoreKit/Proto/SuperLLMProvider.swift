import Foundation
import AgentToolKit
import OSLog

/// 模型能力声明
public struct LLMModelCapabilities: Sendable, Equatable {
    /// 是否支持视觉输入（图片）
    public let supportsVision: Bool
    /// 是否支持工具调用
    public let supportsTools: Bool
    /// 是否支持文本转语音（TTS）
    public let supportsTTS: Bool

    public init(
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
    }
}

/// 单个模型的声明信息
public struct LLMModelSpec: Sendable, Equatable {
    /// 上下文窗口大小（Token 数）
    public let contextWindowSize: Int?
    /// 模型能力
    public let capabilities: LLMModelCapabilities

    public init(
        contextWindowSize: Int? = nil,
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false
    ) {
        self.contextWindowSize = contextWindowSize
        self.capabilities = .init(
            supportsVision: supportsVision,
            supportsTools: supportsTools,
            supportsTTS: supportsTTS
        )
    }
}

/// 模型目录条目（有序）
public struct LLMModelCatalogItem: Sendable, Equatable {
    public let id: String
    public let description: String
    public let spec: LLMModelSpec

    public init(id: String, description: String, spec: LLMModelSpec) {
        self.id = id
        self.description = description
        self.spec = spec
    }
}

public struct LLMProviderResponse: Sendable, Equatable {
    public let content: String
    public let toolCalls: [AgentToolKit.ToolCall]?
    public let thinkingContent: String?

    public init(content: String, toolCalls: [AgentToolKit.ToolCall]?, thinkingContent: String? = nil) {
        self.content = content
        self.toolCalls = toolCalls
        self.thinkingContent = thinkingContent
    }
}

/// 模型可用性检测策略
///
/// 供应商通过此枚举告诉检测器如何检测指定模型的可用性。
public enum AvailabilityCheckStrategy: Sendable {
    /// 使用标准对话 ping 检测（发送一条简短消息验证连通性）
    ///
    /// 适用于绝大多数对话类模型。
    /// - Parameter maxTokens: 可选，限制 ping 请求的最大 token 数以节省开销
    case chatPing(maxTokens: Int? = nil)

    /// 跳过网络请求，仅验证 API Key 已配置即视为可用
    ///
    /// 适用于非对话类模型（如 TTS、Embedding 等），这些模型的 API
    /// 不是 chat/completions 格式，无法通过发送聊天消息来检测。
    case apiKeyOnly

    /// 使用自定义检测逻辑
    ///
    /// 供应商可自行决定检测方式，如发送特定的 HTTP 请求。
    /// - Parameter check: 自定义异步检测闭包，返回是否可用及可选的原因
    case custom(check: @Sendable (String, String) async -> (isAvailable: Bool, reason: String?))
}

/// LLM 供应商协议
///
/// 定义 LLM 供应商必须实现的接口，用于统一不同供应商的接入方式。
public protocol SuperLLMProvider: Sendable {

    /// 供应商实例构造函数
    init()

    // MARK: - Basic Info

    static var id: String { get }
    static var displayName: String { get }
    /// 供应商简写名称
    ///
    /// 用于工具栏等空间受限的 UI 区域显示。
    /// 如 "OpenAI" → "OA", "DeepSeek" → "DS"。
    /// 默认返回 displayName。
    static var shortName: String { get }
    static var description: String { get }
    static var isEnabled: Bool { get }
    static var websiteURL: String? { get }

    // MARK: - Configuration

    static var apiKeyStorageKey: String { get }
    static var defaultModel: String { get }
    static var modelCatalog: [LLMModelCatalogItem] { get }
    static var availableModels: [String] { get }
    static var modelSpecs: [String: LLMModelSpec] { get }
    static var contextWindowSizes: [String: Int] { get }
    static var modelCapabilities: [String: LLMModelCapabilities] { get }
    static var modelDescriptions: [String: String] { get }

    // MARK: - API

    var baseURL: String { get }

    func buildRequest(url: URL, apiKey: String) -> URLRequest
    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]
    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?)
    func parseResponseWithMetadata(data: Data) throws -> LLMProviderResponse
    func parseStreamChunk(data: Data) throws -> StreamChunk?
    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any]

    // MARK: - Availability

    /// 返回指定模型的可用性检测策略
    ///
    /// 检测器会根据返回的策略决定如何检测该模型。
    /// 默认实现根据 `supportsTTS` 能力标志自动选择策略：
    /// - TTS 模型 → `.apiKeyOnly`（仅验证 API Key）
    /// - 其他模型 → `.chatPing()`（发送聊天 ping）
    ///
    /// 供应商可覆盖此方法提供更精细的控制。
    ///
    /// - Parameter modelId: 模型 ID
    /// - Returns: 该模型的检测策略
    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy
}

// MARK: - Default Implementation

extension SuperLLMProvider {
    public static var shortName: String { displayName }
    public static var isEnabled: Bool { true }
    public static var websiteURL: String? { nil }
    public static var modelCatalog: [LLMModelCatalogItem] { [] }
    public static var availableModels: [String] { modelCatalog.map(\.id) }
    public static var modelSpecs: [String: LLMModelSpec] {
        Dictionary(uniqueKeysWithValues: modelCatalog.map { ($0.id, $0.spec) })
    }
    public static var contextWindowSizes: [String: Int] {
        var result: [String: Int] = [:]
        for (model, spec) in modelSpecs {
            if let context = spec.contextWindowSize {
                result[model] = context
            }
        }
        return result
    }
    public static var modelCapabilities: [String: LLMModelCapabilities] {
        Dictionary(uniqueKeysWithValues: modelSpecs.map { ($0.key, $0.value.capabilities) })
    }
    public static var modelDescriptions: [String: String] {
        Dictionary(uniqueKeysWithValues: modelCatalog.map { ($0.id, $0.description) })
    }

    public func parseResponseWithMetadata(data: Data) throws -> LLMProviderResponse {
        let result = try parseResponse(data: data)
        return LLMProviderResponse(content: result.content, toolCalls: result.toolCalls)
    }

    public func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        // TTS 模型不支持对话，仅验证 API Key
        if let caps = Self.modelCapabilities[modelId], caps.supportsTTS {
            return .apiKeyOnly
        }
        // 默认：标准聊天 ping
        return .chatPing()
    }
}
