import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 新版 V1 的 AgentTurn 记录（由消息重建的展示快照）。
///
/// 旧版从持久化的 `AgentTurnManaging.turnRecords` 分页加载 turn；新版
/// `AgentTurnProviding` 只提供运行状态、没有记录存储，因此这里从
/// `Message.turnID` 分组重建：每条有 turnID 的消息归属到对应 turn，
/// `startedAt` = 组内最早 createdAt，`endedAt` = 组内最晚 createdAt。
/// 运行状态来自 `AgentTurnProviding.state(for:)`：当会话处于 running 时，
/// 最新一条 turn 记录标记为运行中（其余历史 turn 视为已完成）。
struct AgentTurnRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let startedAt: Date
    let endedAt: Date?
    let state: AgentLoopState

    var isFinished: Bool {
        switch state {
        case .completed, .failed, .cancelled: return true
        case .idle, .running, .suspended: return false
        }
    }
}

/// 从消息重建 turn 记录（按 startedAt 升序）。
@MainActor
enum AgentTurnRecordBuilder {
    static func records(
        from messages: [Message],
        conversationID: UUID,
        conversationState: AgentLoopState
    ) -> [AgentTurnRecord] {
        let grouped = Dictionary(grouping: messages.compactMap { message -> (UUID, Message)? in
            guard let turnID = message.turnID, message.conversationID == conversationID else { return nil }
            return (turnID, message)
        }, by: \.0)

        let chronological = grouped.values
            .map { pairs -> AgentTurnRecord in
                let turnMessages = pairs.map(\.1).sorted(by: messageOrdering)
                let first = turnMessages[0]
                return AgentTurnRecord(
                    id: first.turnID ?? first.id,
                    conversationID: conversationID,
                    startedAt: first.createdAt,
                    endedAt: turnMessages.last?.createdAt,
                    state: .completed
                )
            }
            .sorted(by: recordOrdering)

        // 会话运行中：最新一条 turn 视为活跃（进行中），其余历史 turn 保持已完成。
        guard conversationState == .running, let latest = chronological.last else {
            return chronological
        }
        var result = chronological
        result[result.count - 1] = AgentTurnRecord(
            id: latest.id,
            conversationID: latest.conversationID,
            startedAt: latest.startedAt,
            endedAt: latest.endedAt,
            state: .running
        )
        return result
    }

    private static func recordOrdering(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.startedAt < rhs.startedAt
    }
}
