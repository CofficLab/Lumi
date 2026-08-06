import Foundation
import LumiKernel

/// Projects the verbose message timeline into one user-facing response per
/// AgentTurn for the brief (V1) presentation.
struct AgentTurnSummaryBuilder {
    func build(
        records: [AgentTurnRecord],
        messages: [LumiChatMessage]
    ) -> [AgentTurnSummaryItem] {
        let messagesByTurn = Dictionary(grouping: messages.compactMap { message in
            message.turnID.map { ($0, message) }
        }, by: \.0)

        return records
            .sorted(by: recordOrdering)
            .compactMap { record in
                let turnMessages = (messagesByTurn[record.id] ?? [])
                    .map(\.1)
                    .sorted(by: messageOrdering)
                guard let message = summaryMessage(for: record, messages: turnMessages) else {
                    return nil
                }
                return AgentTurnSummaryItem(record: record, message: message)
            }
    }

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
        case .idle, .running, .suspended, .cancelled:
            return latestAssistant ?? latestError
        }
    }

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
}
