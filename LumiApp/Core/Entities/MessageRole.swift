import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    /// 工具执行结果消息，展示在聊天中、发送给 LLM 时由 Provider 转为各 API 的 tool_result 格式
    case tool
    /// UI 状态消息（如：连接中/等待响应/生成中），不应持久化或发送给 LLM
    case status
}

public extension MessageRole {
    /// 是否应该发送到 LLM 作为对话上下文的一部分
    var shouldSendToLLM: Bool {
        switch self {
        case .user, .assistant, .tool:
            return true
        case .system, .status:
            return false
        }
    }

    /// 是否应该展示在消息列表中（聊天 UI）
    var shouldDisplayInChatList: Bool {
        switch self {
        case .user, .assistant, .system, .tool, .status:
            return true
        }
    }
}
