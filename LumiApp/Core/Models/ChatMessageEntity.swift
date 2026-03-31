import Foundation
import SwiftData

/// 聊天消息实体
@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    private var _role: String  // 内部存储为 String
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
    
    /// 性能指标和请求元数据（1:1 关系，可选）
    @Relationship(deleteRule: .cascade)
    var metrics: MessageMetricsEntity?

    // 反向关系
    var conversation: Conversation?
    
    /// 消息角色（类型安全的计算属性）
    ///
    /// 从内部 `_role` 字符串转换为 `MessageRole` 枚举。
    /// 如果遇到无法识别的角色值，返回 `.unknown` 而不是默认值，
    /// 这样可以帮助发现数据问题或版本不兼容的情况。
    var role: MessageRole {
        get {
            if let recognized = MessageRole(rawValue: _role) {
                return recognized
            }
            
            // 无法识别的角色，记录警告并返回 .unknown
            AppLogger.core.warning("⚠️ 无法识别的消息角色: '\(self._role)'，消息ID: \(self.id)")
            return .unknown
        }
        set {
            _role = newValue.rawValue
        }
    }
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(),
         isError: Bool = false, toolCallsData: Data? = nil,
         toolCallID: String? = nil,
         providerId: String? = nil, modelName: String? = nil) {
        self.id = id
        self._role = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCallsData = toolCallsData
        self.toolCallID = toolCallID
        self.providerId = providerId
        self.modelName = modelName
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
        let _ = self._role
        let _ = self.content
        
        // 使用计算属性获取类型安全的 MessageRole
        let messageRole = role
        
        // 如果是未知角色，记录警告但仍返回消息（便于UI显示和清理）
        if messageRole == .unknown {
            AppLogger.core.warning("⚠️ 消息 \(self.id) 包含未知角色: '\(self._role)'")
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

        // 从 metrics 关系中获取性能数据
        var latency: Double?
        var inputTokens: Int?
        var outputTokens: Int?
        var totalTokens: Int?
        var timeToFirstToken: Double?
        var streamingDuration: Double?
        var thinkingDuration: Double?
        var finishReason: String?
        var requestId: String?
        var temperature: Double?
        var maxTokens: Int?
        var thinkingContent: String?
        
        if let metrics = metrics {
            latency = metrics.latency
            inputTokens = metrics.inputTokens
            outputTokens = metrics.outputTokens
            totalTokens = metrics.totalTokens
            timeToFirstToken = metrics.timeToFirstToken
            streamingDuration = metrics.streamingDuration
            thinkingDuration = metrics.thinkingDuration
            finishReason = metrics.finishReason
            requestId = metrics.requestId
            temperature = metrics.temperature
            maxTokens = metrics.maxTokens
            thinkingContent = metrics.thinkingContent
        }

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
    /// 此方法仅更新消息自身字段和性能指标。
    func apply(from message: ChatMessage, in context: ModelContext) {
        // 使用计算属性设置类型安全的角色
        role = message.role
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
        
        // 更新或创建性能指标
        if message.hasPerformanceData {
            if let existingMetrics = metrics {
                // 更新现有指标
                existingMetrics.latency = message.latency
                existingMetrics.inputTokens = message.inputTokens
                existingMetrics.outputTokens = message.outputTokens
                existingMetrics.totalTokens = message.totalTokens
                existingMetrics.timeToFirstToken = message.timeToFirstToken
                existingMetrics.streamingDuration = message.streamingDuration
                existingMetrics.thinkingDuration = message.thinkingDuration
                existingMetrics.finishReason = message.finishReason
                existingMetrics.requestId = message.requestId
                existingMetrics.temperature = message.temperature
                existingMetrics.maxTokens = message.maxTokens
                existingMetrics.thinkingContent = message.thinkingContent
                existingMetrics.hasThinking = message.thinkingContent != nil && !message.thinkingContent!.isEmpty
            } else {
                // 创建新指标
                let newMetrics = MessageMetricsEntity.from(message)
                context.insert(newMetrics)
                metrics = newMetrics
            }
        } else {
            // 删除现有指标（如果存在）
            if let existingMetrics = metrics {
                context.delete(existingMetrics)
                metrics = nil
            }
        }
    }

    /// 从 ChatMessage 创建（不含图片关系，图片由 ChatHistoryService 单独处理）
    static func fromChatMessage(_ message: ChatMessage, in context: ModelContext) -> ChatMessageEntity {
        var toolCallsData: Data?
        if let toolCalls = message.toolCalls {
            toolCallsData = try? JSONEncoder().encode(toolCalls)
        }

        let entity = ChatMessageEntity(
            id: message.id,
            role: message.role,  // 类型安全的枚举
            content: message.content,
            timestamp: message.timestamp,
            isError: message.isError,
            toolCallsData: toolCallsData,
            toolCallID: message.toolCallID,
            providerId: message.providerId,
            modelName: message.modelName
        )
        
        // 创建性能指标（如果有数据）
        if message.hasPerformanceData {
            let metricsEntity = MessageMetricsEntity.from(message)
            context.insert(metricsEntity)
            entity.metrics = metricsEntity
        }
        
        return entity
    }
}

// MARK: - Helper Extension

private extension ChatMessage {
    /// 是否包含性能数据
    var hasPerformanceData: Bool {
        latency != nil ||
        inputTokens != nil ||
        outputTokens != nil ||
        totalTokens != nil ||
        timeToFirstToken != nil ||
        streamingDuration != nil ||
        thinkingDuration != nil ||
        finishReason != nil ||
        requestId != nil ||
        temperature != nil ||
        maxTokens != nil ||
        (thinkingContent != nil && !thinkingContent!.isEmpty)
    }
}
