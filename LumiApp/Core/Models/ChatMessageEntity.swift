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
    
    // LLM Metadata - 记录大模型供应商和模型名称
    var providerId: String?      // 例如："anthropic", "openai", "zhipu"
    var modelName: String?       // 例如："claude-sonnet-4-20250514", "gpt-4o"
    
    // Performance Metrics - 性能指标
    var latency: Double?         // 请求总耗时（毫秒）

    // Thinking Process - 思考过程
    var thinkingContent: String? // 思考过程文本（用于 reasoning 模型）
    var hasThinking: Bool = false // 是否有思考过程（便于查询，必须有默认值用于迁移）

    // 反向关系
    var conversation: Conversation?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(),
         isError: Bool = false, toolCallsData: Data? = nil,
         toolCallID: String? = nil, imagesData: Data? = nil,
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, thinkingContent: String? = nil,
         hasThinking: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCallsData = toolCallsData
        self.toolCallID = toolCallID
        self.imagesData = imagesData
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
        self.thinkingContent = thinkingContent
        self.hasThinking = hasThinking
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
        
        return ChatMessage(
            id: id,
            role: messageRole,
            content: content,
            timestamp: timestamp,
            isError: isError,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            images: images,
            providerId: providerId,
            modelName: modelName,
            latency: latency,
            thinkingContent: thinkingContent
        )
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
            imagesData: imagesData,
            providerId: message.providerId,
            modelName: message.modelName,
            latency: message.latency,
            thinkingContent: message.thinkingContent,
            hasThinking: message.thinkingContent != nil && !message.thinkingContent!.isEmpty
        )
    }
}
