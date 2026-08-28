import Foundation
import ProviderMessage

/// `ProviderMessage.Message` → adapter 使用的 `ChatMessage` 桥接。
///
/// 完整搬运：角色、正文、工具调用（assistant 历史回传）、工具结果 id
/// （tool 消息）、思考内容、工具结果图片（`MessageToolResult.imageAttachments`）。
///
/// 注意：adapter 复制的 `CoreModels.swift` 自带 `MessageRole`，与
/// `ProviderMessage.MessageRole` 同名，因此这里显式使用全限定名。
public enum VendorMessageBridging {

    public static func chatMessage(from message: ProviderMessage.Message) -> ChatMessage {
        ChatMessage(
            id: message.id,
            role: role(from: message.role),
            content: message.content,
            toolCalls: message.toolCalls?.map {
                ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            toolCallID: message.toolCallID,
            reasoningContent: message.reasoningContent,
            images: images(from: message)
        )
    }

    public static func chatMessages(from messages: [ProviderMessage.Message]) -> [ChatMessage] {
        messages.map(chatMessage(from:))
    }

    /// 工具结果图片：`MessageToolCall.result.imageAttachments`（base64 data）。
    private static func images(from message: ProviderMessage.Message) -> [MessageImage] {
        let attachments = (message.toolCalls ?? []).compactMap { $0.result?.imageAttachments }.flatMap { $0 }
        return attachments.map {
            MessageImage(
                data: Data(base64Encoded: $0.data) ?? Data(),
                mimeType: $0.mimeType
            )
        }
    }

    private static func role(from role: ProviderMessage.MessageRole) -> MessageRole {
        switch role {
        case .system: return .system
        case .user: return .user
        case .assistant: return .assistant
        case .tool: return .tool
        case .error: return .error
        case .status: return .status
        }
    }
}
