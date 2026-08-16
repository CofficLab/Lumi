import Foundation

public struct LLMModelCapabilities: Sendable, Equatable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsTTS: Bool  // 是否支持文本转语音（TTS）

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

public struct LLMModelSpec: Sendable, Equatable {
    public let contextWindowSize: Int?
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

public enum MessageRole: String, Codable, Sendable, Equatable {
    case system
    case user
    case assistant
    case tool
    case status
    case error
    case unknown
}

public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public var toolCalls: [ToolCall]?
    public var toolCallID: String?
    public var reasoningContent: String?
    public var images: [MessageImage]

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        toolCalls: [ToolCall]? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil,
        images: [MessageImage] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
        self.images = images
    }
}

public enum StreamEventType: String, Sendable, Equatable {
    case messageStart = "message_start"
    case messageDelta = "message_delta"
    case messageStop = "message_stop"
    case contentBlockStart = "content_block_start"
    case contentBlockDelta = "content_block_delta"
    case contentBlockStop = "content_block_stop"
    case thinkingDelta = "thinking_delta"
    case textDelta = "text_delta"
    case inputJsonDelta = "input_json_delta"
    case signatureDelta = "signature_delta"
    case ping
    case unknown
}

public struct StreamChunk: Sendable, Equatable {
    public let content: String?
    public let isDone: Bool
    public let toolCalls: [ToolCall]?
    public let error: String?
    public let partialJson: String?
    /// 当前工具调用增量所属的 index（OpenAI 流式 `tool_calls[].index`），
    /// 用于跨 chunk 把 arguments 分片精确累积到同一个工具调用上。
    public let toolCallIndex: Int?
    public let eventType: StreamEventType?
    public let rawEvent: String?
    public let rawStreamPayload: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cachedInputTokens: Int?
    public let cacheWriteInputTokens: Int?
    public let cacheTotalInputTokens: Int?
    public let stopReason: String?

    public init(
        content: String? = nil,
        isDone: Bool = false,
        toolCalls: [ToolCall]? = nil,
        error: String? = nil,
        partialJson: String? = nil,
        toolCallIndex: Int? = nil,
        eventType: StreamEventType? = nil,
        rawEvent: String? = nil,
        rawStreamPayload: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        cacheWriteInputTokens: Int? = nil,
        cacheTotalInputTokens: Int? = nil,
        stopReason: String? = nil
    ) {
        self.content = content
        self.isDone = isDone
        self.toolCalls = toolCalls
        self.error = error
        self.partialJson = partialJson
        self.toolCallIndex = toolCallIndex
        self.eventType = eventType
        self.rawEvent = rawEvent
        self.rawStreamPayload = rawStreamPayload
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteInputTokens = cacheWriteInputTokens
        self.cacheTotalInputTokens = cacheTotalInputTokens
        self.stopReason = stopReason
    }

    public func withRawStreamPayload(_ raw: String?) -> StreamChunk {
        StreamChunk(
            content: content,
            isDone: isDone,
            toolCalls: toolCalls,
            error: error,
            partialJson: partialJson,
            toolCallIndex: toolCallIndex,
            eventType: eventType,
            rawEvent: rawEvent,
            rawStreamPayload: raw,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens,
            cacheTotalInputTokens: cacheTotalInputTokens,
            stopReason: stopReason
        )
    }

    /// 用替换后的 toolCalls 重建 chunk（其余字段保持不变）。
    ///
    /// 供流式请求支持层把模型返回的 sanitize 后工具名反查为原始注册名时使用。
    public func withToolCalls(_ newToolCalls: [ToolCall]?) -> StreamChunk {
        StreamChunk(
            content: content,
            isDone: isDone,
            toolCalls: newToolCalls,
            error: error,
            partialJson: partialJson,
            toolCallIndex: toolCallIndex,
            eventType: eventType,
            rawEvent: rawEvent,
            rawStreamPayload: rawStreamPayload,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens,
            cacheTotalInputTokens: cacheTotalInputTokens,
            stopReason: stopReason
        )
    }
}
