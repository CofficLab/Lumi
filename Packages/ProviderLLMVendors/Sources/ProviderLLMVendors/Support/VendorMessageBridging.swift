import Foundation
import ProviderMessage

/// `ProviderMessage.Message` → adapter 使用的 `ChatMessage` 桥接。
///
/// 新版消息模型没有图片附件等扩展字段，因此转换是简单的角色映射 +
/// 内容搬运；工具调用等字段由 adapter 层（`ToolCall`）在请求构建时处理。
///
/// 注意：adapter 复制的 `CoreModels.swift` 自带 `MessageRole`，与
/// `ProviderMessage.MessageRole` 同名，因此这里显式使用全限定名。
public enum VendorMessageBridging {

    public static func chatMessage(from message: ProviderMessage.Message) -> ChatMessage {
        ChatMessage(
            role: role(from: message.role),
            content: message.content
        )
    }

    public static func chatMessages(from messages: [ProviderMessage.Message]) -> [ChatMessage] {
        messages.map(chatMessage(from:))
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
