import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    /// 系统消息，不展示在聊天中，发送给 LLM，适合放系统级提示词
    case system
    /// 工具执行结果消息，展示在聊天中、发送给 LLM 时由 Provider 转为各 API 的 tool_result 格式
    case tool
    /// UI 状态消息（如：连接中/等待响应/生成中），不应持久化或发送给 LLM
    case status
    /// 错误消息，展示在聊天中，不应发送给 LLM
    case error
}
