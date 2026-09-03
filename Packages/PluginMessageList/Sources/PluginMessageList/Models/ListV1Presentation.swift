import Foundation
import ProviderMessage

/// V1 列表的唯一展示容器：每项对应一个 `AgentTurnView`。
struct ListV1Presentation: Equatable {
    var agentTurns: [AgentTurnPresentationItem] = []
    var timelineEvents: [Message] = []

    /// V1 按 Agent Turn 聚合，真正发生上下文压缩时的事件保持为独立行。
    var rows: [ListV1PresentationRow] {
        (agentTurns.map(ListV1PresentationRow.agentTurn)
            + timelineEvents.map(ListV1PresentationRow.timelineEvent))
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString > rhs.id.uuidString }
                return lhs.createdAt > rhs.createdAt
            }
    }
}

enum ListV1PresentationRow: Identifiable, Equatable, Sendable {
    case agentTurn(AgentTurnPresentationItem)
    case timelineEvent(Message)

    var id: UUID {
        switch self {
        case let .agentTurn(item): item.id
        case let .timelineEvent(message): message.id
        }
    }

    var createdAt: Date {
        switch self {
        case let .agentTurn(item): item.startedAt
        case let .timelineEvent(message): message.createdAt
        }
    }
}

/// V1 列表唯一面对的展示单元。无论真实 Turn 是否已经建立，List 都只渲染
/// `AgentTurnView`；具体消息组合与阶段切换由该视图自己负责。
struct AgentTurnPresentationItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let startedAt: Date
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
        startedAt = item.record.startedAt
        record = item.record
        pendingAnchorMessageID = nil
        self.acceptsLiveActivity = acceptsLiveActivity
    }

    init(
        pendingUserMessages: [Message],
        statusMessage: Message?
    ) {
        let fallbackID = statusMessage?.id ?? UUID()
        id = pendingUserMessages.first?.id ?? fallbackID
        conversationID = pendingUserMessages.first?.conversationID
            ?? statusMessage?.conversationID
            ?? UUID()
        startedAt = pendingUserMessages.first?.createdAt
            ?? statusMessage?.createdAt
            ?? Date()
        record = nil
        pendingAnchorMessageID = pendingUserMessages.first?.id
        acceptsLiveActivity = true
    }
}
