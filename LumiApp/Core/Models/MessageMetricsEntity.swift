import Foundation
import SwiftData

/// 消息性能指标实体
///
/// 存储消息的性能数据和请求元数据。
/// 通过 1:1 关系关联到 ChatMessageEntity，可选存在。
@Model
final class MessageMetricsEntity {
    /// 关联的消息 ID（唯一标识）
    @Attribute(.unique) var messageId: UUID
    
    // MARK: - Performance Metrics
    
    /// 请求总耗时（毫秒）
    var latency: Double?
    
    /// 输入 token 数量
    var inputTokens: Int?
    
    /// 输出 token 数量
    var outputTokens: Int?
    
    /// 总 token 数量
    var totalTokens: Int?
    
    /// 首 token 延迟（毫秒）
    var timeToFirstToken: Double?
    
    /// 流式传输耗时（毫秒）
    var streamingDuration: Double?
    
    /// 思考过程耗时（毫秒）
    var thinkingDuration: Double?
    
    // MARK: - Request Metadata
    
    /// 完成原因（stop/max_tokens/tool_calls 等）
    var finishReason: String?
    
    /// 供应商请求 ID（用于问题追踪）
    var requestId: String?
    
    /// 生成时使用的 temperature 参数
    var temperature: Double?
    
    /// 生成时使用的 max_tokens 参数
    var maxTokens: Int?
    
    /// 思考过程文本
    var thinkingContent: String?
    
    /// 是否有思考过程（便于查询）
    var hasThinking: Bool = false
    
    // MARK: - Relationships
    
    /// 关联的消息
    var message: ChatMessageEntity?
    
    init(
        messageId: UUID,
        latency: Double? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        timeToFirstToken: Double? = nil,
        streamingDuration: Double? = nil,
        thinkingDuration: Double? = nil,
        finishReason: String? = nil,
        requestId: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        thinkingContent: String? = nil,
        hasThinking: Bool = false
    ) {
        self.messageId = messageId
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
    
    /// 从 ChatMessage 创建指标实体
    static func from(_ message: ChatMessage) -> MessageMetricsEntity {
        MessageMetricsEntity(
            messageId: message.id,
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
    
    /// 将指标应用到 ChatMessage
    func apply(to message: inout ChatMessage) {
        message.latency = latency
        message.inputTokens = inputTokens
        message.outputTokens = outputTokens
        message.totalTokens = totalTokens
        message.timeToFirstToken = timeToFirstToken
        message.streamingDuration = streamingDuration
        message.thinkingDuration = thinkingDuration
        message.finishReason = finishReason
        message.requestId = requestId
        message.temperature = temperature
        message.maxTokens = maxTokens
        message.thinkingContent = thinkingContent
    }
}
