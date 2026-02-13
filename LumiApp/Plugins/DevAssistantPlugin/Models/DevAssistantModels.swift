import Foundation
import SwiftUI

// MARK: - Message Role

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Chat Message

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

// MARK: - Tool Call

struct ToolCall: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let arguments: String
}

// MARK: - LLM Config

struct LLMConfig: Codable, Sendable, Equatable {
    var apiKey: String
    var model: String
    var providerId: String

    static let `default` = LLMConfig(apiKey: "", model: "claude-sonnet-4-20250514", providerId: "anthropic")
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
