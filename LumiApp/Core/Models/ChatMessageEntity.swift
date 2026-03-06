import Foundation
import SwiftData

/// 聊天消息实体（SwiftData 版本）
@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var role: String  // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var isError: Bool
    var toolCallsData: Data?  // 序列化的 ToolCall
    var toolCallID: String?
    var imagesData: Data?  // 序列化的 ImageAttachment
    
    // 反向关系
    var conversation: Conversation?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), isError: Bool = false, toolCallsData: Data? = nil, toolCallID: String? = nil, imagesData: Data? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCallsData = toolCallsData
        self.toolCallID = toolCallID
        self.imagesData = imagesData
    }
    
    /// 转换为 ChatMessage
    func toChatMessage() -> ChatMessage? {
        guard let messageRole = MessageRole(rawValue: role) else {
            return nil
        }
        
        var toolCalls: [ToolCall]?
        if let toolCallsData = toolCallsData {
            toolCalls = try? JSONDecoder().decode([ToolCall].self, from: toolCallsData)
        }
        
        var images: [ImageAttachment] = []
        if let imagesData = imagesData {
            images = try! JSONDecoder().decode([ImageAttachment].self, from: imagesData)
        }
        
        var message = ChatMessage(
            role: messageRole,
            content: content,
            isError: isError,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            images: images
        )
        
        // 使用实体的 ID，避免生成重复 ID
        message = ChatMessage(
            id: id,
            role: messageRole,
            content: content,
            timestamp: timestamp,
            isError: isError,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            images: images
        )
        
        return message
    }
    
    /// 从 ChatMessage 创建
    static func fromChatMessage(_ message: ChatMessage) -> ChatMessageEntity {
        var toolCallsData: Data?
        if let toolCalls = message.toolCalls {
            toolCallsData = try? JSONEncoder().encode(toolCalls)
        }
        
        var imagesData: Data?
        if !message.images.isEmpty {
            imagesData = try? JSONEncoder().encode(message.images)
        }
        
        return ChatMessageEntity(
            id: message.id,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            isError: message.isError,
            toolCallsData: toolCallsData,
            toolCallID: message.toolCallID,
            imagesData: imagesData
        )
    }
}
