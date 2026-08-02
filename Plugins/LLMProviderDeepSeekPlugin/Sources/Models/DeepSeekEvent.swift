import Foundation

/// 单个流式事件（来自 DeepSeek SSE）的解码结果。
///
/// 仅承载协议字段，不做任何行为。`DeepSeekEventParser` 负责构造，
/// `DeepSeekStreamState` 负责消费。
struct DeepSeekEvent: Sendable {
    let content: String?
    let reasoning: String?
    let toolDeltas: [DeepSeekToolDelta]
    let stopReason: String?
    let done: Bool
    let error: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheHitTokens: Int?
    let cacheTotalInputTokens: Int?
}
