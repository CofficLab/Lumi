import Foundation
import LumiKernel

/// One compact V1 row: a persisted AgentTurn paired with its triggering user
/// message (when recoverable) and the turn's user-facing terminal (or latest
/// recoverable / in-flight placeholder) message.
struct AgentTurnSummaryItem: Identifiable, Equatable, Sendable {
    let record: AgentTurnRecord
    /// 触发该 turn 的用户消息。用户消息不携带 turnID(MessageSender 在 turnID
    /// 生成前已落库),这里由 builder 按 `record.startedAt` 之前最近的一条
    /// `.user` 消息时间回溯匹配,可能为 nil(例如首条或无法匹配时)。
    let userMessage: LumiChatMessage?
    /// 该 turn 的最终回复;turn 运行中且尚无任何助手消息时为合成的占位消息。
    let message: LumiChatMessage

    var id: UUID { record.id }
}
