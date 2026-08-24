import Foundation
import KernelLumi

/// V2 (standard/detailed) projector: full message history with streaming and
/// status merging.
///
/// Behavior is aligned 1:1 with the SwiftUI `MessageListRowBuilder`:
/// - `.sending` stage keeps the persisted status row and shows no streaming row.
/// - `.thinking` / `.generating` stages drop the status row and expose the
///   streaming tail as a separate row (never rebuilt into history).
/// - `.idle` shows no streaming row; status rows are shown as persisted.
/// - V1 (`brief`) verbosity drops standalone `.tool` rows and merges
///   consecutive tool-execution-only assistant messages into one synthesized
///   `toolStepGroup` row that reuses the first message's identity.
///
/// The projector is a pure function: the coordinator extracts `streamingStage`
/// and `streamingRow` from `MessageStreaming` before calling it, so tests can
/// drive every stage without a live service.
public struct TimelineProjector: Sendable {
    public init() {}

    public struct Input: Sendable {
        /// Persisted messages of the window, in time order (status included).
        public let persisted: [LumiChatMessage]
        public let verbosity: LumiResponseVerbosity
        /// Current streaming stage; `.idle` when nothing is streaming.
        public let streamingStage: ChatStage
        /// The live streaming row for the conversation, nil when absent.
        public let streamingRow: LumiChatMessage?

        public init(
            persisted: [LumiChatMessage],
            verbosity: LumiResponseVerbosity,
            streamingStage: ChatStage = .idle,
            streamingRow: LumiChatMessage? = nil
        ) {
            self.persisted = persisted
            self.verbosity = verbosity
            self.streamingStage = streamingStage
            self.streamingRow = streamingRow
        }
    }

    /// Stable history rows only (no streaming tail).
    public func projectHistory(_ input: Input) -> [AppKitMessageRow] {
        let dropStatus = shouldShowStreamingRow(input)
        let dropToolRows = input.verbosity == .brief

        let filtered = input.persisted.filter { message in
            if dropStatus, message.role == .status { return false }
            if dropToolRows, message.role == .tool { return false }
            return true
        }

        return Self.mergeConsecutiveToolExecutionMessages(filtered)
            .map { AppKitMessageRow.from(message: $0) }
    }

    /// The live streaming tail row, when the stage makes it visible.
    ///
    /// The row uses the process-wide stable `LumiStreamingRowID` so its identity
    /// never collides with persisted message UUIDs and survives token updates.
    public func projectStreamingRow(_ input: Input) -> AppKitMessageRow? {
        guard shouldShowStreamingRow(input), let row = input.streamingRow else { return nil }
        return AppKitMessageRow(
            id: LumiStreamingRowID.uuidString,
            kind: .streaming,
            message: row,
            sourceTurnID: row.turnID
        )
    }

    /// Full display rows (history + tail), equivalent to the SwiftUI
    /// `build(persisted:...)` entry point.
    public func project(_ input: Input) -> [AppKitMessageRow] {
        var rows = projectHistory(input)
        if let streaming = projectStreamingRow(input) {
            rows.append(streaming)
        }
        return rows
    }

    // MARK: - Streaming visibility

    private func shouldShowStreamingRow(_ input: Input) -> Bool {
        guard input.streamingRow != nil else { return false }
        return input.streamingStage == .thinking || input.streamingStage == .generating
    }

    // MARK: - Tool execution merging (mirror of MessageListRowBuilder)

    static func mergeConsecutiveToolExecutionMessages(
        _ messages: [LumiChatMessage]
    ) -> [LumiChatMessage] {
        var result: [LumiChatMessage] = []
        var currentGroup: [LumiChatMessage] = []
        var currentTurnID: UUID?
        var turnGroups: [UUID: [LumiChatMessage]] = [:]
        var turnGroupIndices: [UUID: Int] = [:]

        func flushGroup() {
            guard !currentGroup.isEmpty else { return }
            result.append(makeToolStepGroup(from: currentGroup))
            currentGroup = []
            currentTurnID = nil
        }

        for message in messages {
            if message.isToolExecutionOnly {
                if let turnID = message.turnID {
                    flushGroup()
                    turnGroups[turnID, default: []].append(message)
                    let group = turnGroups[turnID] ?? []
                    if let index = turnGroupIndices[turnID] {
                        result[index] = makeToolStepGroup(from: group)
                    } else {
                        turnGroupIndices[turnID] = result.count
                        result.append(makeToolStepGroup(from: group))
                    }
                } else {
                    if !currentGroup.isEmpty, currentTurnID != nil {
                        flushGroup()
                    }
                    currentGroup.append(message)
                    currentTurnID = nil
                }
            } else {
                flushGroup()
                result.append(message)
            }
        }
        flushGroup()
        return result
    }

    static func makeToolStepGroup(from messages: [LumiChatMessage]) -> LumiChatMessage {
        let head = messages.first
            ?? LumiChatMessage(conversationID: UUID(), role: .assistant, content: "")
        let allToolCalls = messages.flatMap { $0.toolCalls ?? [] }
        return LumiChatMessage(
            id: head.id,
            conversationID: head.conversationID,
            role: .assistant,
            content: head.content,
            turnID: head.turnID,
            createdAt: head.createdAt,
            providerID: head.providerID,
            modelName: head.modelName,
            isError: head.isError,
            renderKind: head.turnID == nil ? "tool-step-group" : "turn-activity",
            metadata: head.metadata,
            toolCalls: allToolCalls
        )
    }
}
