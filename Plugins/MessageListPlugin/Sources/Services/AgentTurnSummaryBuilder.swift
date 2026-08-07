import Foundation
import LumiKernel

/// Projects the verbose message timeline into one user-facing row per
/// AgentTurn for the brief (V1) presentation.
///
/// 每个 turn 产出**一个** `AgentTurnSummaryItem`,包含:
/// - `userMessage`:触发该 turn 的用户消息(按时间回溯匹配,见下);
/// - `message`:该 turn 的最终回复,或运行中/无内容时的占位。
///
/// **用户消息关联**:用户消息不携带 turnID(`MessageSender` 在 turnID 生成前
/// 已落库),`AgentTurnRecord.triggerMessageID` 也几乎总是 nil。这里改在展示层
/// 解决:把会话消息按时间排序后,对每个 record 取 `startedAt` 之前最近的一条
/// `.user` 消息作为 `userMessage` —— 天然就是触发该 turn 的用户输入,
/// 不依赖 turnID / triggerMessageID,也不动运行时与持久化。
///
/// **运行中 turn**:`.running` / `.idle` 也产出一行。若有中间助手消息就显示它,
/// 否则合成一条"思考中…"占位(`role = .status`)。这样运行中的 turn 始终在
/// 列表里,不再依赖漂浮的 status 行。
struct AgentTurnSummaryBuilder {
    func build(
        records: [AgentTurnRecord],
        messages: [LumiChatMessage]
    ) -> [AgentTurnSummaryItem] {
        // turn 自身的消息仍按 turnID 分组(助手/工具/错误消息携带 turnID)。
        let messagesByTurn = Dictionary(grouping: messages.compactMap { message in
            message.turnID.map { ($0, message) }
        }, by: \.0)

        // 用户消息回溯匹配需要按时间升序的全量消息流。
        let chronological = messages.sorted(by: messageOrdering)

        return records
            .sorted(by: recordOrdering)
            .map { record -> AgentTurnSummaryItem in
                let turnMessages = (messagesByTurn[record.id] ?? [])
                    .map(\.1)
                    .sorted(by: messageOrdering)
                let user = userMessage(before: chronological, startedAt: record.startedAt)
                let message = summaryMessage(for: record, messages: turnMessages)
                    ?? placeholderMessage(for: record)
                return AgentTurnSummaryItem(record: record, userMessage: user, message: message)
            }
    }

    // MARK: - User message matching

    /// 取 `startedAt` 之前(含同时刻)最近的一条 `.user` 消息。
    /// 按时间回溯,用户消息无 turnID 也能正确归属到它触发的 turn。
    private func userMessage(
        before messages: [LumiChatMessage],
        startedAt: Date
    ) -> LumiChatMessage? {
        // messages 已按 createdAt 升序。倒序找第一条 .user 且 createdAt <= startedAt。
        for message in messages.reversed() where message.role == .user {
            if message.createdAt <= startedAt {
                return message
            }
        }
        return nil
    }

    // MARK: - Summary message selection

    private func summaryMessage(
        for record: AgentTurnRecord,
        messages: [LumiChatMessage]
    ) -> LumiChatMessage? {
        let finalAssistant = messages.last(where: isFinalAssistant)
        let latestAssistant = messages.last(where: { $0.role == .assistant })
        let latestError = messages.last(where: { $0.role == .error || $0.isError })

        switch record.state {
        case .completed:
            // Historical records currently derive `.completed` from endedAt,
            // so a provider failure may no longer retain its live `.failed`
            // state after relaunch. A later persisted error must still win over
            // an earlier partial assistant response.
            if let latestError {
                guard let finalAssistant else { return latestError }
                if messageOrdering(finalAssistant, latestError) { return latestError }
            }
            return finalAssistant ?? latestError ?? latestAssistant
        case .failed:
            return latestError ?? finalAssistant ?? latestAssistant
        case .suspended:
            return latestAssistant ?? latestError
        case .cancelled:
            return finalAssistant ?? latestError
        case .running:
            // 运行中:只展示最终回复(无工具调用的助手消息),过程消息不暴露。
            // 若尚无最终回复,交给上层合成占位。
            return finalAssistant ?? latestError
        case .idle:
            // idle 但已有消息(如历史数据)也能展示。
            return finalAssistant ?? latestError
        }
    }

    /// turn 运行中且尚无任何助手消息时,合成一条占位 status 消息。
    /// 复用一个稳定的合成 id(由 turnID 派生),保证 SwiftUI ForEach diff 稳定。
    private func placeholderMessage(for record: AgentTurnRecord) -> LumiChatMessage {
        LumiChatMessage(
            id: Self.placeholderMessageID(for: record.id),
            conversationID: record.conversationID,
            role: .status,
            content: Self.placeholderContent,
            turnID: record.id,
            createdAt: record.startedAt
        )
    }

    // MARK: - Helpers

    private func isFinalAssistant(_ message: LumiChatMessage) -> Bool {
        guard message.role == .assistant,
              !message.isError,
              message.toolCalls?.isEmpty != false else { return false }
        return !message.isEmptyResponse
    }

    private func recordOrdering(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.startedAt < rhs.startedAt
    }

    private func messageOrdering(_ lhs: LumiChatMessage, _ rhs: LumiChatMessage) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt < rhs.createdAt
    }

    private static let placeholderContent = "…"

    /// 由 turnID 确定性派生的占位消息 id。同一 turn 多次重建得到同一 id,
    /// SwiftUI 不会把它当成新行重插。
    private static func placeholderMessageID(for turnID: UUID) -> UUID {
        // 取 turnID 的前 16 字节并翻转一个高位 bit,与真实消息 id 空间隔离,
        // 确定性且零冲突。
        var bytes = turnID.uuid
        bytes.0 |= 0x80
        return UUID(uuid: bytes)
    }
}
