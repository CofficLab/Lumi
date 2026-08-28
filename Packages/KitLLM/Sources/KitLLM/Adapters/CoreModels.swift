import Foundation

// MARK: - 模型元数据

public struct LLMModelCapabilities: Sendable, Equatable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsTTS: Bool

    public init(supportsVision: Bool, supportsTools: Bool, supportsTTS: Bool = false) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
    }
}

public struct LLMModelSpec: Sendable, Equatable {
    public let contextWindowSize: Int?
    public let capabilities: LLMModelCapabilities

    public init(contextWindowSize: Int? = nil, supportsVision: Bool, supportsTools: Bool, supportsTTS: Bool = false) {
        self.contextWindowSize = contextWindowSize
        self.capabilities = .init(supportsVision: supportsVision, supportsTools: supportsTools, supportsTTS: supportsTTS)
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

// MARK: - 适配器内部类型

/// 适配器内部使用的工具调用（流式解析中间态）。
/// 等同于 `LLMToolCall`，保留为独立类型以便适配器内部自由扩展。
public typealias ToolCall = LLMToolCall

/// 流式事件类型。
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

/// 流式解析块（适配器内部使用）。
public struct StreamChunk: Sendable, Equatable {
    public let content: String?
    public let isDone: Bool
    public let toolCalls: [ToolCall]?
    public let error: String?
    public let partialJson: String?
    public let toolCallIndex: Int?
    public let eventType: StreamEventType?
    public let rawEvent: String?
    public let rawStreamPayload: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cachedInputTokens: Int?
    public let cacheWriteInputTokens: Int?
    public let cacheTotalInputTokens: Int?
    public let responseID: String?
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
        responseID: String? = nil,
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
        self.responseID = responseID
        self.stopReason = stopReason
    }

    public func withRawStreamPayload(_ raw: String?) -> StreamChunk {
        StreamChunk(content: content, isDone: isDone, toolCalls: toolCalls, error: error, partialJson: partialJson, toolCallIndex: toolCallIndex, eventType: eventType, rawEvent: rawEvent, rawStreamPayload: raw, inputTokens: inputTokens, outputTokens: outputTokens, cachedInputTokens: cachedInputTokens, cacheWriteInputTokens: cacheWriteInputTokens, cacheTotalInputTokens: cacheTotalInputTokens, responseID: responseID, stopReason: stopReason)
    }

    public func withToolCalls(_ newToolCalls: [ToolCall]?) -> StreamChunk {
        StreamChunk(content: content, isDone: isDone, toolCalls: newToolCalls, error: error, partialJson: partialJson, toolCallIndex: toolCallIndex, eventType: eventType, rawEvent: rawEvent, rawStreamPayload: rawStreamPayload, inputTokens: inputTokens, outputTokens: outputTokens, cachedInputTokens: cachedInputTokens, cacheWriteInputTokens: cacheWriteInputTokens, cacheTotalInputTokens: cacheTotalInputTokens, responseID: responseID, stopReason: stopReason)
    }
}
