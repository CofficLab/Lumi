import Foundation
import SwiftUI

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

    // Tool Use Support
    var toolCalls: [ToolCall]?
    var toolCallID: String? // If this message is a tool_result, this links to the request

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

struct ToolCall: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let arguments: String // JSON string
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
    case zhipu = "Zhipu AI"

    var id: String { rawValue }

    var defaultBaseURL: String? {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .deepseek: return "https://api.deepseek.com/chat/completions"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        }
    }

    var availableModels: [String] {
        switch self {
        case .anthropic:
            return [
                "claude-3-5-sonnet-20240620",
                "claude-3-opus-20240229",
                "claude-3-sonnet-20240229",
                "claude-3-haiku-20240307",
            ]
        case .openai:
            return [
                "gpt-4o",
                "gpt-4-turbo",
                "gpt-4",
                "gpt-3.5-turbo",
            ]
        case .deepseek:
            return [
                "deepseek-chat",
                "deepseek-coder",
            ]
        case .zhipu:
            return [
                "GLM-4.7",
            ]
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
