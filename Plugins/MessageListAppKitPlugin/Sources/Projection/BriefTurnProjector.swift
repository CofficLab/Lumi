import Foundation
import LumiKernel

/// V1 (brief) projector: collapses every AgentTurn into exactly one
/// user-facing conclusion row, plus at most one trailing status row.
///
/// Behavior is aligned 1:1 with the SwiftUI `MessageListV1ViewModel` +
/// `AgentTurnSummaryBuilder`:
/// - `idle` / `running` turns emit no conclusion row.
/// - `completed` prefers the last non-tool assistant conclusion; a *later*
///   persisted error wins over an earlier partial response.
/// - `failed` prefers the latest error, then conclusion, then any assistant.
/// - `suspended` prefers the latest assistant, then error.
/// - `cancelled` prefers the conclusion, then error.
/// - When no turn records exist (legacy conversations), errors and final
///   assistant conclusions are emitted directly.
public struct BriefTurnProjector: Sendable {
    public init() {}

    public struct Input: Sendable {
        /// Turn records for the loaded page, any order (sorted internally).
        public let records: [AgentTurnRecord]
        /// All messages of the conversation, in time order.
        public let messages: [LumiChatMessage]
        /// The single status row to append at the end (nil allowed).
        public let statusMessage: LumiChatMessage?

        public init(
            records: [AgentTurnRecord],
            messages: [LumiChatMessage],
            statusMessage: LumiChatMessage?
        ) {
            self.records = records
            self.messages = messages
            self.statusMessage = statusMessage
        }
    }

    public func project(_ input: Input) -> [AppKitMessageRow] {
        let conclusionRows: [AppKitMessageRow]
        if input.records.isEmpty {
            conclusionRows = legacyRows(from: input.messages)
        } else {
            conclusionRows = turnRows(records: input.records, messages: input.messages)
        }

        if let status = input.statusMessage {
            return conclusionRows + [AppKitMessageRow(kind: .status, message: status)]
        }
        return conclusionRows
    }

    // MARK: - Turn conclusion rows

    private func turnRows(
        records: [AgentTurnRecord],
        messages: [LumiChatMessage]
    ) -> [AppKitMessageRow] {
        let messagesByTurn = Dictionary(
            grouping: messages.compactMap { message in
                message.turnID.map { ($0, message) }
            },
            by: \.0
        )

        return records
            .sorted(by: recordOrdering)
            .compactMap { record in
                let turnMessages = (messagesByTurn[record.id] ?? [])
                    .map(\.1)
                    .sorted(by: messageOrdering)
                guard let message = summaryMessage(for: record, messages: turnMessages) else {
                    return nil
                }
                return AppKitMessageRow(
                    id: "turn-\(record.id.uuidString)",
                    kind: .conclusion,
                    message: message,
                    sourceTurnID: record.id
                )
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
        case .idle, .running:
            return nil
        }
    }

    // MARK: - Legacy rows (no turn identity)

    private func legacyRows(from messages: [LumiChatMessage]) -> [AppKitMessageRow] {
        messages.compactMap { message in
            if message.role == .error || message.isError {
                return AppKitMessageRow(kind: .conclusion, message: message)
            }
            guard isFinalAssistant(message) else { return nil }
            return AppKitMessageRow(kind: .conclusion, message: message)
        }
    }

    // MARK: - Predicates / ordering (mirror of AgentTurnSummaryBuilder)

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
