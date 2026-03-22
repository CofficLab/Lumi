import Foundation

/// 流式响应数据块
struct StreamChunk: Sendable {
    /// 文本内容片段
    let content: String?
    /// 是否结束
    let isDone: Bool
    /// 工具调用（如果有）
    let toolCalls: [ToolCall]?
    /// 错误信息（如果有）
    let error: String?
    /// 工具调用参数的 JSON 分片（用于流式传输）
    let partialJson: String?
    /// 事件类型
    let eventType: StreamEventType?
    /// 原始事件数据（用于调试和展示）
    let rawEvent: String?
    /// 输入 token 数量（从 message_start 或 message_delta 中获取）
    let inputTokens: Int?
    /// 输出 token 数量（从 message_delta 中获取）
    let outputTokens: Int?
    /// 完成原因（从 message_delta 中获取）
    let stopReason: String?

    init(
        content: String? = nil,
        isDone: Bool = false,
        toolCalls: [ToolCall]? = nil,
        error: String? = nil,
        partialJson: String? = nil,
        eventType: StreamEventType? = nil,
        rawEvent: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        stopReason: String? = nil
    ) {
        self.content = content
        self.isDone = isDone
        self.toolCalls = toolCalls
        self.error = error
        self.partialJson = partialJson
        self.eventType = eventType
        self.rawEvent = rawEvent
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.stopReason = stopReason
    }
}
