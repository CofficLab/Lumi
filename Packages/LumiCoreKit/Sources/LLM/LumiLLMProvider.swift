import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    /// 模型可用
    case available
    /// 模型不可用，附带结构化失败信息
    case unavailable(LumiLLMFailureDetail)
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable {
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

public struct LumiLLMProviderInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultModel: String
    public let availableModels: [String]
    public let isLocal: Bool
    public let contextWindowSizes: [String: Int]
    /// 各模型的能力声明（key 为模型 ID）
    public let modelCapabilities: [String: LumiModelCapabilities]
    /// 各模型的展示名称（key 为模型 ID）；未命中时 UI 回退到原始 ID
    public let modelDisplayNames: [String: String]
    /// 供应商官网/控制台页面（用于设置页跳转）
    public let websiteURL: URL
    /// API Key 在 Keychain/UserDefaults 中的存储键；本地供应商为 nil
    public let apiKeyStorageKey: String?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [String],
        isLocal: Bool = false,
        contextWindowSizes: [String: Int] = [:],
        modelCapabilities: [String: LumiModelCapabilities] = [:],
        modelDisplayNames: [String: String] = [:],
        websiteURL: URL,
        apiKeyStorageKey: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.contextWindowSizes = contextWindowSizes
        self.modelCapabilities = modelCapabilities
        self.modelDisplayNames = modelDisplayNames
        self.websiteURL = websiteURL
        // 本地供应商无需 API Key；远程供应商使用传入值或按 id 生成默认键
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}

public struct LumiLLMRequest: Sendable {
    public let messages: [LumiChatMessage]
    public let model: String
    public let tools: [any LumiAgentTool]
    public let imageAttachments: [LumiImageAttachment]

    public init(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool] = [],
        imageAttachments: [LumiImageAttachment] = []
    ) {
        self.messages = messages
        self.model = model
        self.tools = tools
        self.imageAttachments = imageAttachments
    }
}

public protocol LumiLLMProvider: Sendable {
    static var info: LumiLLMProviderInfo { get }

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage

    /// 检查指定模型是否可用。
    /// - Parameter model: 模型名称
    /// - Returns: 模型可用性检测结果
    func checkAvailability(model: String) async -> LumiModelAvailabilityResult

    /// 供应商为模型选择器等 UI 提供的当前状态说明（如缺少 API Key、套餐过期）。
    /// 每个供应商都必须实现；无问题时返回 `nil`。
    func providerStatus() -> LumiLLMProviderStatus?

    /// 供应商对单次失败的重试决策；子类可 override。
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition

    /// 将异常映射为错误消息的 `renderKind`；无自定义渲染时返回 `nil`。
    func errorRenderKind(for error: Error) -> String?

    /// 由调用方在重试耗尽或不可重试时，将 throw 的错误转为可展示的错误消息。
    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage
}

public extension LumiLLMProvider {
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let providing = error as? LumiLLMErrorDispositionProviding {
            return providing.llmErrorDisposition
        }
        return .nonRetryable
    }

    func errorRenderKind(for error: Error) -> String? {
        nil
    }

    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        let metadata = disposition.metadataEntries
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: Self.info.id,
            modelName: request.model,
            isError: true,
            rawErrorDetail: detail,
            metadata: metadata
        )
    }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let message = try await send(request)
        if !message.content.isEmpty {
            await onChunk(LumiStreamChunk(content: message.content, eventTitle: "生成中"))
        }
        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
        return message
    }
}