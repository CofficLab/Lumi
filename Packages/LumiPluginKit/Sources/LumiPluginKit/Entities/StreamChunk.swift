import Foundation
import AgentToolKit

/// 流式响应数据块
public struct StreamChunk: Sendable {
    /// 文本内容片段
    public let content: String?
    /// 是否结束
    public let isDone: Bool
    /// 工具调用（如果有）
    public let toolCalls: [ToolCall]?
    /// 错误信息（如果有）
    public let error: String?
    /// 工具调用参数的 JSON 分片（用于流式传输）
    public let partialJson: String?
    /// 事件类型
    public let eventType: StreamEventType?
    /// 原始事件数据（用于调试和展示）
    public let rawEvent: String?
    /// 本帧对应的原始流数据（未经供应商解析，如单条 SSE 事件体的 UTF-8 文本；由管线注入）
    public let rawStreamPayload: String?
    /// 输入 token 数量（从 message_start 或 message_delta 中获取）
    public let inputTokens: Int?
    /// 输出 token 数量（从 message_delta 中获取）
    public let outputTokens: Int?
    /// 完成原因（从 message_delta 中获取）
    public let stopReason: String?

    public init(
        content: String? = nil,
        isDone: Bool = false,
        toolCalls: [ToolCall]? = nil,
        error: String? = nil,
        partialJson: String? = nil,
        eventType: StreamEventType? = nil,
        rawEvent: String? = nil,
        rawStreamPayload: String? = nil,
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
        self.rawStreamPayload = rawStreamPayload
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.stopReason = stopReason
    }

    /// 复制并写入 `rawStreamPayload`（供 HTTP 流式管线在解析后注入原始分包）。
    public func withRawStreamPayload(_ raw: String?) -> StreamChunk {
        StreamChunk(
            content: content,
            isDone: isDone,
            toolCalls: toolCalls,
            error: error,
            partialJson: partialJson,
            eventType: eventType,
            rawEvent: rawEvent,
            rawStreamPayload: raw,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            stopReason: stopReason
        )
    }

    public func isThinking() -> Bool {
        eventType?.isThinking() ?? false
    }

    public func isReceivingContent() -> Bool {
        eventType?.isReceivingContent() ?? false
    }

    public func getTitle() -> String {
        eventType?.displayName ?? "未知事件"
    }

    public func getContent() -> String {
        content ?? ""
    }
}
