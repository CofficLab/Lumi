import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    /// UI 状态消息（如：连接中/等待响应/生成中），不应持久化或发送给 LLM
    case status
}

public extension MessageRole {
    /// 是否应该发送到 LLM 作为对话上下文的一部分
    var shouldSendToLLM: Bool {
        switch self {
        case .user, .assistant:
            return true
        case .system, .status:
            return false
        }
    }

    /// 是否应该展示在消息列表中（聊天 UI）
    var shouldDisplayInChatList: Bool {
        switch self {
        case .user, .assistant, .status:
            return true
        case .system:
            return true
        }
    }
}
