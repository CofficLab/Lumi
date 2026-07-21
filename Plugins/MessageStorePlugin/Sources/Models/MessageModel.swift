import Foundation
import SwiftData
import LumiCoreMessage

/// SwiftData model for chat messages
///
/// Stored in plugin专属 SQLite database, managed by `MessageStore`.
@Model
final public class MessageModel: @unchecked Sendable {
    /// Unique identifier (UUID)
    public var id: String

    /// Conversation ID
    public var conversationId: String

    /// Message role (user, assistant, system, tool, etc.)
    public var role: String

    /// Message content
    public var content: String

    /// Creation timestamp
    public var createdAt: TimeInterval

    /// Provider ID (e.g., "openai")
    public var providerId: String?

    /// Model name (e.g., "gpt-4")
    public var modelName: String?

    /// Whether this is an error message
    public var isError: Bool

    /// Raw error detail string
    public var rawErrorDetail: String?

    /// Render kind (e.g., "text", "markdown")
    public var renderKind: String?

    /// Metadata as JSON string
    public var metadataJson: String?

    /// Tool calls as JSON string
    public var toolCallsJson: String?

    /// Tool call ID
    public var toolCallId: String?

    /// Reasoning content (thinking)
    public var reasoningContent: String?

    /// Input token count
    public var inputTokenCount: Int?

    /// Output token count
    public var outputTokenCount: Int?

    /// Latency in milliseconds
    public var latencyMs: Double?

    /// Time to first token in milliseconds
    public var timeToFirstTokenMs: Double?

    /// Streaming duration in milliseconds
    public var streamingDurationMs: Double?

    public init(
        id: String = UUID().uuidString,
        conversationId: String,
        role: String,
        content: String,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        providerId: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        renderKind: String? = nil,
        metadataJson: String? = nil,
        toolCallsJson: String? = nil,
        toolCallId: String? = nil,
        reasoningContent: String? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        latencyMs: Double? = nil,
        timeToFirstTokenMs: Double? = nil,
        streamingDurationMs: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerId = providerId
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadataJson = metadataJson
        self.toolCallsJson = toolCallsJson
        self.toolCallId = toolCallId
        self.reasoningContent = reasoningContent
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
    }
}

// MARK: - Conversion

public extension MessageModel {
    /// Convert from LumiChatMessage to MessageModel
    static func from(message: LumiChatMessage) -> MessageModel {
        let encoder = JSONEncoder()
        let metadataData = try? encoder.encode(message.metadata)
        let metadataJson = metadataData.flatMap { String(data: $0, encoding: .utf8) }
        let toolCallsData = try? encoder.encode(message.toolCalls)
        let toolCallsJson = toolCallsData.flatMap { String(data: $0, encoding: .utf8) }

        return MessageModel(
            id: message.id.uuidString,
            conversationId: message.conversationID.uuidString,
            role: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt.timeIntervalSince1970,
            providerId: message.providerID,
            modelName: message.modelName,
            isError: message.isError,
            rawErrorDetail: message.rawErrorDetail,
            renderKind: message.renderKind,
            metadataJson: metadataJson,
            toolCallsJson: toolCallsJson,
            toolCallId: message.toolCallID,
            reasoningContent: message.reasoningContent,
            inputTokenCount: message.inputTokenCount,
            outputTokenCount: message.outputTokenCount,
            latencyMs: message.latencyMs,
            timeToFirstTokenMs: message.timeToFirstTokenMs,
            streamingDurationMs: message.streamingDurationMs
        )
    }

    /// Convert to LumiChatMessage
    func toLumiChatMessage() -> LumiChatMessage? {
        guard let uuid = UUID(uuidString: id),
              let conversationUUID = UUID(uuidString: conversationId),
              let chatRole = LumiChatMessageRole(rawValue: role) else {
            return nil
        }

        let decoder = JSONDecoder()
        let metadata: [String: String] = metadataJson.flatMap {
            try? decoder.decode([String: String].self, from: Data($0.utf8))
        } ?? [:]
        let toolCalls: [LumiToolCall]? = toolCallsJson.flatMap {
            try? decoder.decode([LumiToolCall].self, from: Data($0.utf8))
        }

        return LumiChatMessage(
            id: uuid,
            conversationID: conversationUUID,
            role: chatRole,
            content: content,
            createdAt: Date(timeIntervalSince1970: createdAt),
            providerID: providerId,
            modelName: modelName,
            isError: isError,
            rawErrorDetail: rawErrorDetail,
            renderKind: renderKind,
            metadata: metadata,
            toolCalls: toolCalls,
            toolCallID: toolCallId,
            reasoningContent: reasoningContent,
            inputTokenCount: inputTokenCount,
            outputTokenCount: outputTokenCount,
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            streamingDurationMs: streamingDurationMs
        )
    }
}
