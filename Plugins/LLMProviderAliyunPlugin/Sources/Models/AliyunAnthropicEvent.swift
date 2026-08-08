import Foundation

/// 阿里云 Anthropic 协议单个 SSE 事件解码结果。
struct AliyunAnthropicEvent: Sendable {
    let textDelta: String?
    let thinkingDelta: String?
    let toolInputJSONDelta: String?
    let toolName: String?
    let toolID: String?
    let stopReason: String?
    let stopSequence: String?
    let usage: AliyunAnthropicUsage?
    let done: Bool
    let error: String?

    init(
        textDelta: String? = nil,
        thinkingDelta: String? = nil,
        toolInputJSONDelta: String? = nil,
        toolName: String? = nil,
        toolID: String? = nil,
        stopReason: String? = nil,
        stopSequence: String? = nil,
        usage: AliyunAnthropicUsage? = nil,
        done: Bool = false,
        error: String? = nil
    ) {
        self.textDelta = textDelta
        self.thinkingDelta = thinkingDelta
        self.toolInputJSONDelta = toolInputJSONDelta
        self.toolName = toolName
        self.toolID = toolID
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
        self.done = done
        self.error = error
    }
}

struct AliyunAnthropicUsage: Sendable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
}
