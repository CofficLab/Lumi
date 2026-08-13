import Foundation
import KernelLumi

/// One V1 AgentTurn presentation: its triggering user message, chronological
/// live process, and the terminal result selected for the collapsed state.
struct AgentTurnSummaryItem: Identifiable, Equatable, Sendable {
    let record: AgentTurnRecord
    /// 触发该 turn 的用户消息。用户消息不携带 turnID(MessageSender 在 turnID
    /// 生成前已落库),这里由 builder 按 `record.startedAt` 之前最近的一条
    /// `.user` 消息时间回溯匹配,可能为 nil(例如首条或无法匹配时)。
    let userMessage: LumiChatMessage?
    /// Turn 内用于解释执行过程的消息，按时间升序排列。最终结果与 `.tool` 原始输出
    /// 不会出现在这里；工具调用本身仍由携带 `toolCalls` 的 assistant 消息展示。
    let processMessages: [LumiChatMessage]
    /// 该 turn 的最终回复;turn 运行中且尚无任何助手消息时为合成的占位消息。
    let message: LumiChatMessage

    var id: UUID { record.id }
    var isShowingProcess: Bool { !record.isFinished }
}
