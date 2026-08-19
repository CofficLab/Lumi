import Foundation

// MARK: - 消息角色

/// 消息角色。
public enum MessageRole: String, Codable, Sendable, Equatable {
    case system
    case user
    case assistant
    case tool
    case status
    case error
    case unknown
}

// MARK: - Kit 级消息类型

/// LLM 消息（协议适配器层使用）。
public struct LLMMessage: Sendable, Equatable {
    public let role: MessageRole
    public var content: String
    public var toolCalls: [LLMToolCall]?
    public var toolCallID: String?
    public var reasoningContent: String?
    public var images: [MessageImage]

    public init(
        role: MessageRole,
        content: String,
        toolCalls: [LLMToolCall]? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil,
        images: [MessageImage] = []
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
        self.images = images
    }
}

/// LLM 工具调用。
public struct LLMToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// 工具 schema 描述。
public struct LLMFunctionSchema: @unchecked Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [String: Any]

    public init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public static func == (lhs: LLMFunctionSchema, rhs: LLMFunctionSchema) -> Bool {
        lhs.name == rhs.name
            && lhs.description == rhs.description
            && NSDictionary(dictionary: lhs.parameters).isEqual(to: rhs.parameters)
    }
}

// MARK: - LLMRequest / LLMResponse

/// LLM 完成请求。
public struct LLMRequest: Sendable {
    public let conversationID: UUID
    public let messages: [LLMMessage]
    public let model: String?
    public let tools: [LLMFunctionSchema]?
    public let reasoningEffort: String?

    public init(
        conversationID: UUID = UUID(),
        messages: [LLMMessage],
        model: String? = nil,
        tools: [LLMFunctionSchema]? = nil,
        reasoningEffort: String? = nil
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.model = model
        self.tools = tools
        self.reasoningEffort = reasoningEffort
    }
}

/// LLM 完成响应。
public struct LLMResponse: Sendable, Equatable {
    public let content: String
    public let model: String?
    public let toolCalls: [LLMToolCall]?
    public let reasoningContent: String?
    public let inputTokenCount: Int?
    public let outputTokenCount: Int?
    public let cachedInputTokenCount: Int?
    public let stopReason: String?

    public init(
        content: String,
        model: String? = nil,
        toolCalls: [LLMToolCall]? = nil,
        reasoningContent: String? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        cachedInputTokenCount: Int? = nil,
        stopReason: String? = nil
    ) {
        self.content = content
        self.model = model
        self.toolCalls = toolCalls
        self.reasoningContent = reasoningContent
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokenCount = cachedInputTokenCount
        self.stopReason = stopReason
    }
}

/// 流式输出块。
public struct LLMStreamChunk: Sendable {
    public let content: String?
    public let reasoningContent: String?
    public let isDone: Bool
    public let eventTitle: String?
    public let toolCalls: [LLMToolCall]?

    public init(
        content: String? = nil,
        reasoningContent: String? = nil,
        isDone: Bool = false,
        eventTitle: String? = nil,
        toolCalls: [LLMToolCall]? = nil
    ) {
        self.content = content
        self.reasoningContent = reasoningContent
        self.isDone = isDone
        self.eventTitle = eventTitle
        self.toolCalls = toolCalls
    }
}

// MARK: - 流式协议

public protocol LLMStreamingProviding: AnyObject, Sendable {
    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse
}

// MARK: - 错误

public enum LLMProviderError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured
    case emptyResponse
    case providerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "LLM provider is not configured"
        case .emptyResponse: return "LLM provider returned an empty response"
        case .providerUnavailable(let reason): return "LLM provider unavailable: \(reason)"
        }
    }
}

/// 默认空实现。
public final class DefaultLLMProviding: SuperLLMProvider, @unchecked Sendable {
    public let providerInfo: LLMProviderInfo
    public var providerID: String { providerInfo.id }

    public init(providerID: String = "default") {
        self.providerInfo = LLMProviderInfo(
            id: providerID,
            displayName: "Default",
            defaultModel: "",
            models: [],
            isLocal: true
        )
    }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        throw LLMProviderError.notConfigured
    }
}
