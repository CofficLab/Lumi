import Foundation

/// 单个流式事件（来自 StepFun SSE）的解码结果。
///
/// 仅承载协议字段，不做任何行为。`StepFunEventParser` 负责构造，
/// `StepFunChatMessage` 负责消费。
struct StepFunEvent: Sendable {
    let content: String?
    let toolDeltas: [StepFunToolDelta]
    let stopReason: String?
    let done: Bool
    let error: String?
    let inputTokens: Int?
    let outputTokens: Int?
}