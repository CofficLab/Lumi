import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isError: Bool = false
    
    init(role: MessageRole, content: String, isError: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
    }
}

struct LLMConfig: Codable, Sendable, Equatable {
    var apiKey: String
    var model: String
    var provider: LLMProvider
    
    static let `default` = LLMConfig(apiKey: "", model: "claude-3-5-sonnet-20240620", provider: .anthropic)
}

enum LLMProvider: String, Codable, Sendable, CaseIterable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"
}
