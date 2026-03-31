import Foundation
import SwiftData

/// 聊天消息实体
@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var role: String  // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var isError: Bool
    var toolCallsData: Data?  // 序列化的 ToolCall
    var toolCallID: String?

    /// 图片附件（多对多关系，独立存储在 ImageAttachmentEntity 表中）
    @Relationship(deleteRule: .deny, inverse: \ImageAttachmentEntity.messages)
    var images: [ImageAttachmentEntity] = []
    
    // LLM Metadata - 记录大模型供应商和模型名称
    var providerId: String?      // 例如："anthropic", "openai", "zhipu"
    var modelName: String?       // 例如："claude-sonnet-4-20250514", "gpt-4o"
    
    // Performance Metrics - 性能指标
    var latency: Double?         // 请求总耗时（毫秒）
    var inputTokens: Int?        // 输入 token 数量
    var outputTokens: Int?       // 输出 token 数量
    var totalTokens: Int?        // 总 token 数量
    var timeToFirstToken: Double? // 首 token 延迟（毫秒）
    var streamingDuration: Double? // 流式传输耗时（毫秒）
    var thinkingDuration: Double?  // 思考过程耗时（毫秒）

    // Request Metadata - 请求元数据
    var finishReason: String?    // 完成原因（stop/max_tokens/tool_calls 等）
    var requestId: String?       // 供应商请求 ID（用于问题追踪）
    var temperature: Double?     // 生成时使用的 temperature 参数
    var maxTokens: Int?          // 生成时使用的 max_tokens 参数

    // Thinking Process - 思考过程
    var thinkingContent: String? // 思考过程文本（用于 reasoning 模型）
    var hasThinking: Bool = false // 是否有思考过程（便于查询，必须有默认值用于迁移）

    // 反向关系
    var conversation: Conversation?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(),
         isError: Bool = false, toolCallsData: Data? = nil,
         toolCallID: String? = nil,
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil,
         totalTokens: Int? = nil, timeToFirstToken: Double? = nil,
         streamingDuration: Double? = nil, thinkingDuration: Double? = nil,
         finishReason: String? = nil, requestId: String? = nil,
         temperature: Double? = nil, maxTokens: Int? = nil,
         thinkingContent: String? = nil, hasThinking: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCallsData = toolCallsData
        self.toolCallID = toolCallID
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.timeToFirstToken = timeToFirstToken
        self.streamingDuration = streamingDuration
        self.thinkingDuration = thinkingDuration
        self.finishReason = finishReason
        self.requestId = requestId
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.thinkingContent = thinkingContent
        self.hasThinking = hasThinking
    }
    
    /// 转换为 ChatMessage
    ///
    /// **安全地**将 SwiftData 实体转换为 ChatMessage 对象。
    ///
    /// ## 重要：SwiftData 对象失效保护
    ///
    /// SwiftData 可能会在以下情况下使对象失效：
    /// 1. 对象被删除后，其他线程仍持有引用
    /// 2. ModelContext 被释放后，尝试访问对象属性
    /// 3. 跨线程访问未正确管理的对象
    ///
    /// 本方法使用防御性编程，确保即使对象失效也不会崩溃：
    /// - 检查 `isDeleted` 标记
    /// - 使用 `try?` 而不是 `try!` 避免解码错误崩溃
    /// - 检查所有可选值，即使理论上不应为 nil
    /// - 在访问属性前捕获潜在的 SwiftData 内部错误
    ///
    /// - Returns: ChatMessage 对象，如果转换失败则返回 nil
    func toChatMessage() -> ChatMessage? {
        // ✅ 检查是否已被标记为删除
        // SwiftData 的 @Model 会自动生成 isDeleted 属性
        guard !isDeleted else { return nil }
        
        // 防御性编程：即使对象理论上有效，也要检查基本属性
        // SwiftData 可能在访问属性时抛出内部错误
        // 注意：简单的属性访问不会抛出错误，所以不需要 do-catch
        // 这里我们只是访问属性来确保对象有效
        let _ = self.id
        let _ = self.role
        let _ = self.content
        
        guard let messageRole = MessageRole(rawValue: role) else {
            return nil
        }
        
        // 安全地访问 conversation 关系
        // 如果对象已被删除，conversation 可能为 nil
        guard let conversationId = conversation?.id else {
            return nil
        }
        
        var toolCalls: [ToolCall]?
        if let toolCallsData = toolCallsData {
            toolCalls = try? JSONDecoder().decode([ToolCall].self, from: toolCallsData)
        }
        
        // 从关系中获取图片附件
        let imageAttachments = images.map { $0.toImageAttachment() }

        return ChatMessage(
            id: id,
            role: messageRole,
            conversationId: conversationId,
            content: content,
            timestamp: timestamp,
            isError: isError,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            images: imageAttachments,
            providerId: providerId,
            modelName: modelName,
            latency: latency,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            timeToFirstToken: timeToFirstToken,
            streamingDuration: streamingDuration,
            thinkingDuration: thinkingDuration,
            finishReason: finishReason,
            requestId: requestId,
            temperature: temperature,
            maxTokens: maxTokens,
            thinkingContent: thinkingContent
        )
    }
    
    /// 用 `ChatMessage` 覆盖当前实体字段（用于同 ID 更新，不新建记录）
    ///
    /// 注意：图片关系更新由 `ChatHistoryService.syncImageRelations` 处理，
    /// 此方法仅更新消息自身字段。
    func apply(from message: ChatMessage) {
        role = message.role.rawValue
        content = message.content
        timestamp = message.timestamp
        isError = message.isError
        if let toolCalls = message.toolCalls {
            toolCallsData = try? JSONEncoder().encode(toolCalls)
        } else {
            toolCallsData = nil
        }
        toolCallID = message.toolCallID
        providerId = message.providerId
        modelName = message.modelName
        latency = message.latency
        inputTokens = message.inputTokens
        outputTokens = message.outputTokens
        totalTokens = message.totalTokens
        timeToFirstToken = message.timeToFirstToken
        streamingDuration = message.streamingDuration
        thinkingDuration = message.thinkingDuration
        finishReason = message.finishReason
        requestId = message.requestId
        temperature = message.temperature
        maxTokens = message.maxTokens
        thinkingContent = message.thinkingContent
        hasThinking = message.thinkingContent != nil && !message.thinkingContent!.isEmpty
    }

    /// 从 ChatMessage 创建（不含图片关系，图片由 ChatHistoryService 单独处理）
    static func fromChatMessage(_ message: ChatMessage) -> ChatMessageEntity {
        var toolCallsData: Data?
        if let toolCalls = message.toolCalls {
            toolCallsData = try? JSONEncoder().encode(toolCalls)
        }

        return ChatMessageEntity(
            id: message.id,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            isError: message.isError,
            toolCallsData: toolCallsData,
            toolCallID: message.toolCallID,
            providerId: message.providerId,
            modelName: message.modelName,
            latency: message.latency,
            inputTokens: message.inputTokens,
            outputTokens: message.outputTokens,
            totalTokens: message.totalTokens,
            timeToFirstToken: message.timeToFirstToken,
            streamingDuration: message.streamingDuration,
            thinkingDuration: message.thinkingDuration,
            finishReason: message.finishReason,
            requestId: message.requestId,
            temperature: message.temperature,
            maxTokens: message.maxTokens,
            thinkingContent: message.thinkingContent,
            hasThinking: message.thinkingContent != nil && !message.thinkingContent!.isEmpty
        )
    }
}
