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
    var baseURL: String? // For OpenAI compatible providers
    
    static let `default` = LLMConfig(apiKey: "", model: "claude-3-5-sonnet-20240620", provider: .anthropic)
}

enum LLMProvider: String, Codable, Sendable, CaseIterable, Identifiable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"
    case deepseek = "DeepSeek"
    
    var id: String { rawValue }
    
    var defaultBaseURL: String? {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .deepseek: return "https://api.deepseek.com/chat/completions"
        }
    }
}
