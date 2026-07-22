import Foundation
import LumiKernel

// MARK: - LumiVisionMessageSupport

/// Converts LumiKernel messages → LLMKit ChatMessage for provider consumption.
///
/// LumiVisionMessageSupport.preparedMessages(for:) is the central entry-point used by
/// LumiStreamingRequestSupport to transform a LumiLLMRequest into the provider-specific
/// message array.
public enum LumiVisionMessageSupport {
    public static func preparedMessages(for request: LumiLLMRequest) -> [ChatMessage] {
        var messages = request.messages.map(convert)
        attachRequestImages(&messages, attachments: request.imageAttachments)
        return LLMMessagePreparer.prepare(messages)
    }

    public static func convert(_ message: LumiChatMessage) -> ChatMessage {
        ChatMessage(
            role: convertRole(message.role),
            content: message.content,
            toolCalls: message.toolCalls?.map {
                ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            toolCallID: message.toolCallID,
            images: messageImages(from: message.metadata)
        )
    }

    public static func messageImages(from metadata: [String: String]) -> [MessageImage] {
        guard let json = metadata["imageAttachments"],
              let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder().decode([LumiImageAttachment].self, from: data)
        else {
            return []
        }
        return attachments.compactMap { attachment in
            guard let imageData = Data(base64Encoded: attachment.base64Data) else {
                return nil
            }
            return MessageImage(data: imageData, mimeType: attachment.mimeType)
        }
    }

    private static func attachRequestImages(
        _ messages: inout [ChatMessage],
        attachments: [LumiImageAttachment]
    ) {
        let images = messageImages(
            from: ["imageAttachments": encodeAttachments(attachments) ?? ""]
        )
        guard !images.isEmpty,
              let lastUserIndex = messages.lastIndex(where: { $0.role == .user })
        else {
            return
        }
        if messages[lastUserIndex].images.isEmpty {
            messages[lastUserIndex].images = images
        }
    }

    private static func encodeAttachments(_ attachments: [LumiImageAttachment]) -> String? {
        guard let data = try? JSONEncoder().encode(attachments),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    private static func convertRole(_ role: LumiChatMessageRole) -> MessageRole {
        switch role {
        case .system:   return .system
        case .user:     return .user
        case .assistant: return .assistant
        case .tool:     return .tool
        case .error, .status: return .error
        }
    }
}

// MARK: - LumiLLMRequestMessages

/// Thin bridge: LumiLLMRequest → provider-ready ChatMessage array.
///
/// Delegates to LumiVisionMessageSupport for the actual conversion.
public enum LumiLLMRequestMessages {
    public static func preparedForProvider(_ request: LumiLLMRequest) -> [ChatMessage] {
        LumiVisionMessageSupport.preparedMessages(for: request)
    }
}

// MARK: - LumiToolSchema

/// Wraps a LumiAgentTool (LumiKernel) as LLMToolSchemaProviding (LLMKit).
public struct LumiToolSchema: LLMToolSchemaProviding {
    public let name: String
    public let toolDescription: String
    public let inputSchema: [String: Any]

    public init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
