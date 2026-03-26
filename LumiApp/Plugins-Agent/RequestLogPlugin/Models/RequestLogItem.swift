import Foundation
import SwiftData

/// 请求日志项 - SwiftData 模型
///
/// 存储每次 LLM 请求的完整数据，用于调试和审计。
@Model
final class RequestLogItem {
    // MARK: - 基础信息
    
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 会话 ID
    var conversationId: UUID
    
    /// 时间戳
    var timestamp: Date
    
    // MARK: - 请求信息
    
    /// 请求 URL
    var requestURL: String
    
    /// 请求体大小（字节）
    var requestBodySize: Int
    
    /// LLM 供应商 ID
    var providerId: String?
    
    /// 模型名称
    var modelName: String?
    
    /// Temperature 参数
    var temperature: Double?
    
    /// Max Tokens 参数
    var maxTokens: Int?
    
    /// 消息数量
    var messageCount: Int
    
    /// 消息摘要（JSON 格式）
    var messagesSummary: String?
    
    /// 工具数量
    var toolCount: Int
    
    /// 工具名称列表（逗号分隔）
    var toolNames: String?
    
    /// 临时系统提示词数量
    var transientPromptCount: Int
    
    /// 临时系统提示词摘要
    var transientPromptsSummary: String?
    
    // MARK: - 响应信息
    
    /// 是否成功
    var isSuccess: Bool
    
    /// 错误信息
    var errorMessage: String?
    
    /// 响应内容预览（前 500 字符）
    var responseContentPreview: String?
    
    /// 是否包含工具调用
    var hasToolCalls: Bool
    
    /// 工具调用名称列表
    var toolCallNames: String?
    
    /// 请求延迟（毫秒）
    var latency: Double?
    
    /// 输入 Token 数量
    var inputTokens: Int?
    
    /// 输出 Token 数量
    var outputTokens: Int?
    
    /// 总 Token 数量
    var totalTokens: Int?
    
    /// 完成原因
    var finishReason: String?
    
    // MARK: - 耗时
    
    /// 总耗时（秒）
    var duration: Double?
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        conversationId: UUID,
        timestamp: Date = Date(),
        requestURL: String,
        requestBodySize: Int,
        providerId: String? = nil,
        modelName: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        messageCount: Int = 0,
        messagesSummary: String? = nil,
        toolCount: Int = 0,
        toolNames: String? = nil,
        transientPromptCount: Int = 0,
        transientPromptsSummary: String? = nil,
        isSuccess: Bool = false,
        errorMessage: String? = nil,
        responseContentPreview: String? = nil,
        hasToolCalls: Bool = false,
        toolCallNames: String? = nil,
        latency: Double? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        finishReason: String? = nil,
        duration: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.timestamp = timestamp
        self.requestURL = requestURL
        self.requestBodySize = requestBodySize
        self.providerId = providerId
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.messageCount = messageCount
        self.messagesSummary = messagesSummary
        self.toolCount = toolCount
        self.toolNames = toolNames
        self.transientPromptCount = transientPromptCount
        self.transientPromptsSummary = transientPromptsSummary
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.responseContentPreview = responseContentPreview
        self.hasToolCalls = hasToolCalls
        self.toolCallNames = toolCallNames
        self.latency = latency
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.finishReason = finishReason
        self.duration = duration
    }
    
    // MARK: - 查询谓词
    
    /// 按时间范围查询
    static func predicate(from startTime: Date, to endTime: Date) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }
    
    /// 按会话 ID 查询
    static func predicate(conversationId: UUID) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.conversationId == conversationId
        }
    }
    
    /// 按供应商 ID 查询
    static func predicate(providerId: String) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.providerId == providerId
        }
    }
    
    /// 按成功状态查询
    static func predicate(isSuccess: Bool) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.isSuccess == isSuccess
        }
    }
}

// MARK: - DTO

/// 请求日志 DTO（非持久化，用于返回值）
struct RequestLogItemDTO: Sendable {
    let id: UUID
    let conversationId: UUID
    let timestamp: Date
    let requestURL: String
    let requestBodySize: Int
    let providerId: String?
    let modelName: String?
    let messageCount: Int
    let toolCount: Int
    let isSuccess: Bool
    let errorMessage: String?
    let hasToolCalls: Bool
    let latency: Double?
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
    let duration: Double?
    
    /// 从模型转换为 DTO
    init(from item: RequestLogItem) {
        self.id = item.id
        self.conversationId = item.conversationId
        self.timestamp = item.timestamp
        self.requestURL = item.requestURL
        self.requestBodySize = item.requestBodySize
        self.providerId = item.providerId
        self.modelName = item.modelName
        self.messageCount = item.messageCount
        self.toolCount = item.toolCount
        self.isSuccess = item.isSuccess
        self.errorMessage = item.errorMessage
        self.hasToolCalls = item.hasToolCalls
        self.latency = item.latency
        self.inputTokens = item.inputTokens
        self.outputTokens = item.outputTokens
        self.totalTokens = item.totalTokens
        self.duration = item.duration
    }
}