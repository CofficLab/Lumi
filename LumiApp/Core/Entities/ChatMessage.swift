import Foundation

struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isError: Bool = false

    // Tool Use Support
    var toolCalls: [ToolCall]?
    var toolCallID: String?

    // Image Support
    var images: [ImageAttachment] = []

    // LLM Metadata - 记录大模型供应商和模型名称
    var providerId: String?  // 例如："anthropic", "openai", "zhipu"
    var modelName: String?   // 例如："claude-sonnet-4-20250514", "gpt-4o"

    // Performance Metrics - 性能指标
    var latency: Double?     // 请求总耗时（毫秒）

    init(role: MessageRole, content: String, isError: Bool = false, 
         toolCalls: [ToolCall]? = nil, toolCallID: String? = nil, 
         images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
    }
    
    /// 从数据库加载时使用的初始化方法，保留原有 ID
    init(id: UUID, role: MessageRole, content: String, timestamp: Date, 
         isError: Bool = false, toolCalls: [ToolCall]? = nil, 
         toolCallID: String? = nil, images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
    }

    // 实现 Equatable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.isError == rhs.isError &&
        lhs.images == rhs.images &&
        lhs.providerId == rhs.providerId &&
        lhs.modelName == rhs.modelName &&
        lhs.latency == rhs.latency
    }
}
