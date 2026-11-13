import Foundation
import ProviderMessage
import KitMessageList

/// Projects the verbose message timeline into one user-facing row per
/// AgentTurn for the brief (V1) presentation.
///
/// 每个 turn 产出**一个** `AgentTurnSummaryItem`，包含：
/// - `userMessage`：触发该 turn 的用户消息（按时间回溯匹配，见下）；
/// - `message`：该 turn 的最终回复，或运行中/无内容时的占位。
///
/// **用户消息关联**：用户消息不携带 turnID（发送器在 turnID 生成前已落库），
/// 这里在展示层解决：把会话消息按时间排序后，对每个 record 取 `startedAt` 之前
/// 最近的一条 `.user` 消息作为 `userMessage` —— 天然就是触发该 turn 的用户输入，
/// 不依赖 turnID，也不动运行时与持久化。
///
/// **运行中 turn**：`processMessages` 暴露当前 turn 的助手工具调用、工具结果及
/// 瞬时 status；视图展示这些过程。turn 进入终态后，视图折叠为 `message`。
struct AgentTurnSummaryBuilder {
    func build(
        records: [AgentTurnRecord],
        messages: [Message]
    ) -> [AgentTurnSummaryItem] {
        // turn 自身的消息仍按 turnID 分组（助手/工具/错误消息携带 turnID）。
        let messagesByTurn = Dictionary(grouping: messages.compactMap { message in
            message.turnID.map { ($0, message) }
        }, by: \.0)

        // 用户消息回溯匹配需要按时间升序的全量消息流。
        let chronological = messages.sorted(by: messageOrdering)
        // 无 turnID 的瞬时 status 属于当前会话而非某个历史 turn；只挂到最新活跃 turn。
        let latestActiveTurnID = records
            .filter { !$0.isFinished }
            .max(by: recordOrdering)?
            .id

        // 瞬时 status 的筛选条件与具体 record 无关（只依赖会话），
        // 原先在每个 record 的循环里都对全量消息流做一次线性扫描 ——
        // N 个 record 就是 N 次全量扫描，整体 O(N²)（见 issue #1267）。
        // 这里按会话提前分好组，每个 record 只取自己会话的那一组。
        var transientStatusesByConversation: [UUID: [Message]] = [:]
        for candidate in chronological
        where candidate.role == .status && candidate.turnID == nil {
            transientStatusesByConversation[candidate.conversationID, default: []].append(candidate)
        }

        // `.user` 消息索引：每个 record 用二分查找，避免 O(N²)。
        let userMessages = userMessageIndex(from: chronological)

        return records
            .sorted(by: recordOrdering)
            .map { record -> AgentTurnSummaryItem in
                let turnMessages = (messagesByTurn[record.id] ?? [])
                    .map(\.1)
                    .sorted(by: messageOrdering)
                let user = userMessage(from: userMessages, startedAt: record.startedAt)
                let message = summaryMessage(for: record, messages: turnMessages)
                    ?? placeholderMessage(for: record)
                // 只有最新活跃 turn 才挂瞬时 status。
                let transientStatuses = record.id == latestActiveTurnID
                    ? (transientStatusesByConversation[record.conversationID] ?? [])
                    : []
                let processMessages = (turnMessages + transientStatuses)
                    .filter {
                        $0.id != message.id
                            && $0.role != .user
                            && $0.role != .system
                            // V1 只展示工具正在做什么，不暴露工具的原始返回内容。
                            && $0.role != .tool
                    }
                    .sorted(by: messageOrdering)
                return AgentTurnSummaryItem(
                    record: record,
                    userMessage: user,
                    processMessages: processMessages,
                    message: message
                )
            }
    }

    // MARK: - User message matching

    /// `.user` 消息的时间索引：按时间升序排列，供二分查找。
    ///
    /// 原先每个 record 都从全量消息尾部反向线性扫描找最近的用户消息，
    /// N 个 record 就是 N 次扫描，整体 O(N²)（见 issue #1267）。
    /// 这里只把 `.user` 消息抽出来建一次索引，各 record 用二分查找。
    private func userMessageIndex(from messages: [Message]) -> [Message] {
        messages.filter { $0.role == .user }
    }

    /// 二分查找 `startedAt` 之前（含同时刻）最近的一条 `.user` 消息。
    ///
    /// - Note: `userMessages` 需按 `createdAt` 升序。
    private func userMessage(
        from userMessages: [Message],
        startedAt: Date
    ) -> Message? {
        guard !userMessages.isEmpty else { return nil }

        // 找到第一个 `createdAt > startedAt` 的位置，其前一条就是答案。
        var low = 0
        var high = userMessages.count
        while low < high {
            let mid = (low + high) / 2
            if userMessages[mid].createdAt <= startedAt {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low > 0 ? userMessages[low - 1] : nil
    }

    // MARK: - Summary message selection

    private func summaryMessage(
        for record: AgentTurnRecord,
        messages: [Message]
    ) -> Message? {
        let finalAssistant = messages.last(where: isFinalAssistant)
        let latestAssistant = messages.last(where: { $0.role == .assistant })
        let latestError = messages.last(where: { $0.role == .error || $0.isError })

        switch record.state {
        case .completed:
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
            // 运行中：只展示最终回复（无工具调用的助手消息），过程消息不暴露。
            return finalAssistant ?? latestError
        case .idle:
            return finalAssistant ?? latestError
        }
    }

    /// turn 运行中且尚无任何助手消息时，合成一条占位 status 消息。
    /// 复用一个稳定的合成 id（由 turnID 派生），保证 SwiftUI ForEach diff 稳定。
    private func placeholderMessage(for record: AgentTurnRecord) -> Message {
        Message(
            id: Self.placeholderMessageID(for: record.id),
            conversationID: record.conversationID,
            role: .status,
            content: Self.placeholderContent,
            createdAt: record.startedAt,
            turnID: record.id
        )
    }

    // MARK: - Helpers

    private func isFinalAssistant(_ message: Message) -> Bool {
        guard message.role == .assistant,
              !message.isError,
              message.toolCalls?.isEmpty != false else { return false }
        return !message.isEmptyResponse
    }

    private func recordOrdering(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.startedAt < rhs.startedAt
    }

    private static let placeholderContent = "…"

    /// 由 turnID 确定性派生的占位消息 id。同一 turn 多次重建得到同一 id，
    /// SwiftUI 不会把它当成新行重插。
    private static func placeholderMessageID(for turnID: UUID) -> UUID {
        var bytes = turnID.uuid
        bytes.0 |= 0x80
        return UUID(uuid: bytes)
    }
}
