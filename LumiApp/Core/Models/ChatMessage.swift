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

    init(role: MessageRole, content: String, isError: Bool = false, toolCalls: [ToolCall]? = nil, toolCallID: String? = nil, images: [ImageAttachment] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
    }
    
    /// 从数据库加载时使用的初始化方法，保留原有 ID
    init(id: UUID, role: MessageRole, content: String, timestamp: Date, isError: Bool = false, toolCalls: [ToolCall]? = nil, toolCallID: String? = nil, images: [ImageAttachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
    }

    // 实现 Equatable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.isError == rhs.isError &&
        lhs.images == rhs.images
    }
}
