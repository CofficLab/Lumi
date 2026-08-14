import Foundation

/// 原型设计对话中的本地消息。
///
/// 与内核 `LumiChatMessage` 不同，本插件维护一份**独立**的对话状态：
/// 不写入 `MessageStore`、不进入主聊天的 AgentTurn 流程，从而与日常聊天隔离。
/// 仅在向 LLM 发送请求时通过 `PrototypePromptBuilder` 转换为 `LumiChatMessage`。
struct PrototypeMessage: Identifiable, Sendable {
    enum Role: Sendable {
        case user
        case assistant
    }

    let id: UUID
    var role: Role
    var content: String
    var isError: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        isError: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isError = isError
        self.createdAt = createdAt
    }
}
