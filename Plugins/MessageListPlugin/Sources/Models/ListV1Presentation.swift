import Foundation
import LumiKernel

struct ListV1Presentation: Equatable {
    var agentTurns: [AgentTurnPresentationItem] = []
}

/// V1 列表唯一面对的展示单元。无论真实 Turn 是否已经建立，List 都只渲染
/// `AgentTurnView`；具体消息组合与阶段切换由该视图自己负责。
struct AgentTurnPresentationItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let record: AgentTurnRecord?
    /// Turn 尚未建立时，用这条用户消息作为临时 Turn 的锚点。
    let pendingAnchorMessageID: UUID?
    /// 只有最新活跃 Turn 接收无 turnID 的瞬时 Status 与流式消息。
    let acceptsLiveActivity: Bool

    var isPending: Bool { record == nil }
    var isShowingProcess: Bool { record?.isFinished != true }

    init(recorded item: AgentTurnSummaryItem, acceptsLiveActivity: Bool) {
        // 真实 Turn 始终以 turnID 为身份；即使异常历史数据让多个 Turn 匹配到
        // 同一用户消息，ForEach 也不会产生重复 ID。
        id = item.record.id
        conversationID = item.record.conversationID
        record = item.record
        pendingAnchorMessageID = nil
        self.acceptsLiveActivity = acceptsLiveActivity
    }

    init(
        pendingUserMessages: [LumiChatMessage],
        statusMessage: LumiChatMessage?
    ) {
        let fallbackID = statusMessage?.id ?? UUID()
        id = pendingUserMessages.first?.id ?? fallbackID
        conversationID = pendingUserMessages.first?.conversationID
            ?? statusMessage?.conversationID
            ?? UUID()
        record = nil
        pendingAnchorMessageID = pendingUserMessages.first?.id
        acceptsLiveActivity = true
    }
}
