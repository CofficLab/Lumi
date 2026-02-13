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

    init(role: MessageRole, content: String, isError: Bool = false, toolCalls: [ToolCall]? = nil, toolCallID: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
    }
}
