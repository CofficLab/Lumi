import Foundation

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
    /// 供应商官网/控制台页面（用于设置页跳转；若无则不展示入口）
    public let websiteURL: URL?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [String],
        isLocal: Bool = false,
        contextWindowSizes: [String: Int] = [:],
        modelCapabilities: [String: LumiModelCapabilities] = [:],
        websiteURL: URL? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.contextWindowSizes = contextWindowSizes
        self.modelCapabilities = modelCapabilities
        self.websiteURL = websiteURL
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
}

public extension LumiLLMProvider {
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
