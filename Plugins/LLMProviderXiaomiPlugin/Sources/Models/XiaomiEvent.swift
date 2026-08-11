import Foundation

/// 单个流式事件（来自 Xiaomi SSE）的解码结果。
///
/// 仅承载协议字段，不做任何行为。`XiaomiEventParser` 负责构造。
struct XiaomiEvent: Sendable {
    let content: String?
    let toolDeltas: [XiaomiToolDelta]
    let stopReason: String?
    let done: Bool
    let error: String?
    let inputTokens: Int?
    let outputTokens: Int?
}
