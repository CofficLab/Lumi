import Foundation

/// 等待用户响应的数据结构
///
/// AskUserTool 执行后返回 pending 状态时携带的 JSON payload，
/// 由渲染器解析并显示用户选择界面。
public struct AskUserPendingResponse: Codable, Equatable {
    public let toolCallId: String
    public let question: String
    public let options: [String]
    public let allowFreeInput: Bool
    public let conversationId: String
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [String],
        allowFreeInput: Bool,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.allowFreeInput = allowFreeInput
        self.conversationId = conversationId
        self.verbosity = verbosity
    }
}

/// AskUserTool 执行出错的错误响应数据结构
public struct AskUserErrorResponse: Codable, Equatable {
    public let error: String
}
