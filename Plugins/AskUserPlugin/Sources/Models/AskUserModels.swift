import Foundation

/// 等待用户响应的数据结构
///
/// AskUserTool 执行后返回 pending 状态时携带的 JSON payload，
/// 由渲染器解析并显示用户选择界面。
public struct AskUserPendingResponse: Codable, Equatable {
    public let toolCallId: String
    public let question: String
    public let options: [String]
    /// 交互模式：`"yes_no"` / `"choice"` / `"free_text"`。
    /// 可选是为了兼容旧 payload（早期版本无此字段）；视图层会在 `nil` 时按 `options` 回退推断。
    public let mode: String?
    public let conversationId: String
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [String],
        mode: String?,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.mode = mode
        self.conversationId = conversationId
        self.verbosity = verbosity
    }
}

/// AskUserTool 执行出错的错误响应数据结构
public struct AskUserErrorResponse: Codable, Equatable {
    public let error: String
}
