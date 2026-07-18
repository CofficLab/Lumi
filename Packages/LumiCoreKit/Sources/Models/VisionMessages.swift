import Foundation
import LLMKit
import LumiCoreKit

public enum VisionMessageSupport {
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
        else {
            return nil
        }
        return json
    }

    private static func convertRole(_ role: LumiChatMessageRole) -> MessageRole {
        switch role {
        case .system:
            .system
        case .user:
            .user
        case .assistant:
            .assistant
        case .tool:
            .tool
        case .error, .status:
            .error
        }
    }
}
