import Foundation
import ProviderMessage
import SwiftData

/// SwiftData model for chat messages
@Model
public final class MessageModel {
    /// Unique identifier (UUID 字符串)。
    public var id: String

    /// Conversation ID (UUID 字符串)。
    public var conversationId: String

    /// AgentTurn ID (可选，turn 追踪之前创建的消息为 nil)。
    public var turnId: String?

    /// Message role (rawValue)。
    public var role: String

    /// Message content。
    public var content: String

    /// Creation timestamp (timeIntervalSince1970)。
    public var createdAt: TimeInterval

    /// Provider ID (e.g. "openai")。
    public var providerId: String?

    /// Model name (e.g. "gpt-4")。
    public var modelName: String?

    /// Whether this is an error message。
    public var isError: Bool

    /// Raw error detail string。
    public var rawErrorDetail: String?

    /// HTTP response status code for an error message。
    public var httpStatusCode: Int?

    /// HTTP response body for an error message。
    public var httpBody: String?

    /// Render kind (e.g. "text", "markdown", "tool-step-group")。
    public var renderKind: String?

    /// 期望的渲染器 ID（显式路由）。
    public var preferredRendererId: String?

    /// Tool call ID。
    public var toolCallId: String?

    /// Reasoning content (thinking)。
    public var reasoningContent: String?

    /// Metadata as JSON string。
    public var metadataJson: String?

    /// Tool calls as JSON string (插入时 result 置 nil，轻量化)。
    public var toolCallsJson: String?

    /// Input token count。
    public var inputTokenCount: Int?

    /// Output token count。
    public var outputTokenCount: Int?
    public var cachedInputTokenCount: Int?
    public var cacheWriteInputTokenCount: Int?
    public var cacheTotalInputTokenCount: Int?
    public var responseId: String?
    public var requestId: String?
    public var rawResponseJson: String?
    public var rawStreamEventsJson: String?
    public var stopReason: String?

    /// Latency in milliseconds。
    public var latencyMs: Double?

    /// Time to first token in milliseconds。
    public var timeToFirstTokenMs: Double?

    /// Streaming duration in milliseconds。
    public var streamingDurationMs: Double?

    public init(
        id: String = UUID().uuidString,
        conversationId: String,
        turnId: String? = nil,
        role: String,
        content: String,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        providerId: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        httpStatusCode: Int? = nil,
        httpBody: String? = nil,
        renderKind: String? = nil,
        preferredRendererId: String? = nil,
        toolCallId: String? = nil,
        reasoningContent: String? = nil,
        metadataJson: String? = nil,
        toolCallsJson: String? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        cachedInputTokenCount: Int? = nil,
        cacheWriteInputTokenCount: Int? = nil,
        cacheTotalInputTokenCount: Int? = nil,
        responseId: String? = nil,
        requestId: String? = nil,
        rawResponseJson: String? = nil,
        rawStreamEventsJson: String? = nil,
        stopReason: String? = nil,
        latencyMs: Double? = nil,
        timeToFirstTokenMs: Double? = nil,
        streamingDurationMs: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.turnId = turnId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerId = providerId
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.httpStatusCode = httpStatusCode
        self.httpBody = httpBody
        self.renderKind = renderKind
        self.preferredRendererId = preferredRendererId
        self.toolCallId = toolCallId
        self.reasoningContent = reasoningContent
        self.metadataJson = metadataJson
        self.toolCallsJson = toolCallsJson
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokenCount = cachedInputTokenCount
        self.cacheWriteInputTokenCount = cacheWriteInputTokenCount
        self.cacheTotalInputTokenCount = cacheTotalInputTokenCount
        self.responseId = responseId
        self.requestId = requestId
        self.rawResponseJson = rawResponseJson
        self.rawStreamEventsJson = rawStreamEventsJson
        self.stopReason = stopReason
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
    }
}

// MARK: - Conversion

public extension MessageModel {
    /// Convert from `ProviderMessage.Message` to MessageModel。
    ///
    /// Tool calls 轻量化：`result` 置 nil（工具结果由 ToolManager 持有、
    /// UI 按需加载），仅保留调用元数据；`updateToolCallResult` 随后把结果
    /// 写入消息内展示快照。与旧版 MessageManagerPlugin 策略一致。
    static func from(message: Message) -> MessageModel {
        let encoder = JSONEncoder()
        let metadataData = try? encoder.encode(message.metadata)
        let metadataJson = metadataData.flatMap { String(data: $0, encoding: .utf8) }

        let lightweightToolCalls = message.toolCalls?.map { toolCall -> MessageToolCall in
            var copy = toolCall
            copy.result = nil
            return copy
        }
        let toolCallsData = try? encoder.encode(lightweightToolCalls)
        let toolCallsJson = toolCallsData.flatMap { String(data: $0, encoding: .utf8) }

        return MessageModel(
            id: message.id.uuidString,
            conversationId: message.conversationID.uuidString,
            turnId: message.turnID?.uuidString,
            role: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt.timeIntervalSince1970,
            providerId: message.providerID,
            modelName: message.modelName,
            isError: message.isError,
            rawErrorDetail: message.rawErrorDetail,
            httpStatusCode: message.httpStatusCode,
            httpBody: message.httpBody,
            renderKind: message.renderKind,
            preferredRendererId: message.preferredRendererID,
            toolCallId: message.toolCallID,
            reasoningContent: message.reasoningContent,
            metadataJson: metadataJson,
            toolCallsJson: toolCallsJson,
            inputTokenCount: message.inputTokenCount,
            outputTokenCount: message.outputTokenCount,
            cachedInputTokenCount: message.cachedInputTokenCount,
            cacheWriteInputTokenCount: message.cacheWriteInputTokenCount,
            cacheTotalInputTokenCount: message.cacheTotalInputTokenCount,
            responseId: message.responseID,
            requestId: message.requestID,
            rawResponseJson: message.rawResponseJSON,
            rawStreamEventsJson: message.rawStreamEventsJSON,
            stopReason: message.stopReason,
            latencyMs: message.latencyMs,
            timeToFirstTokenMs: message.timeToFirstTokenMs,
            streamingDurationMs: message.streamingDurationMs
        )
    }

    /// Convert to `ProviderMessage.Message`。
    func toMessage() -> Message? {
        guard let uuid = UUID(uuidString: id),
              let conversationUUID = UUID(uuidString: conversationId),
              let role = MessageRole(rawValue: role) else {
            return nil
        }

        let decoder = JSONDecoder()
        let metadata: [String: String] = metadataJson.flatMap {
            try? decoder.decode([String: String].self, from: Data($0.utf8))
        } ?? [:]
        let toolCalls: [MessageToolCall]? = toolCallsJson.flatMap {
            try? decoder.decode([MessageToolCall].self, from: Data($0.utf8))
        }

        return Message(
            id: uuid,
            conversationID: conversationUUID,
            role: role,
            content: content,
            createdAt: Date(timeIntervalSince1970: createdAt),
            turnID: turnId.flatMap(UUID.init(uuidString:)),
            metadata: metadata,
            isError: isError,
            providerID: providerId,
            modelName: modelName,
            rawErrorDetail: rawErrorDetail,
            httpStatusCode: httpStatusCode,
            httpBody: httpBody,
            renderKind: renderKind,
            preferredRendererID: preferredRendererId,
            toolCallID: toolCallId,
            reasoningContent: reasoningContent,
            toolCalls: toolCalls,
            inputTokenCount: inputTokenCount,
            outputTokenCount: outputTokenCount,
            cachedInputTokenCount: cachedInputTokenCount,
            cacheWriteInputTokenCount: cacheWriteInputTokenCount,
            cacheTotalInputTokenCount: cacheTotalInputTokenCount,
            responseID: responseId,
            requestID: requestId,
            rawResponseJSON: rawResponseJson,
            rawStreamEventsJSON: rawStreamEventsJson,
            stopReason: stopReason,
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            streamingDurationMs: streamingDurationMs
        )
    }
}
