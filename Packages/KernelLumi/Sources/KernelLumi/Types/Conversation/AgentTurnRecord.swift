import Foundation

/// Persistable snapshot describing one AgentTurn within a conversation.
///
/// `AgentTurnRecord` 是 turn 的持久化元数据，与运行时状态 `AgentTurnState` 互补：
/// - `AgentTurnState` 描述**当前活跃** turn 的瞬时生命周期（running/suspended 等）；
/// - `AgentTurnRecord` 描述**每一次** turn 的完整归档（起止时间、token 统计、父子关系等）。
///
/// UI 层（如 AgentTurnList 插件）通过 `AgentTurnManaging.turnRecords(for:)` 拉取记录，
/// 结合 `ToolManaging.toolCalls(for:)` 获取工具调用详情，组成 turn 时间线视图。
public struct AgentTurnRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let conversationID: UUID
    /// Parent turn identifier, when this turn was spawned as a child/sub-agent turn.
    public let parentTurnID: UUID?
    /// ID of the user message that triggered this turn, when known.
    public let triggerMessageID: UUID?
    /// Terminal lifecycle state (completed/failed/cancelled); for live queries the
    /// manager overlays the current `AgentTurnState` on top of the record.
    public let state: AgentTurnState
    public let startedAt: Date
    public let endedAt: Date?
    public let inputTokenCount: Int
    public let outputTokenCount: Int
    /// Number of tool calls invoked during this turn. Stored as a lightweight
    /// counter so the list UI can render progress without iterating tool records.
    public let toolCallCount: Int
    /// Number of tool calls that finished (regardless of success/error).
    public let toolCallCompletedCount: Int
    /// Optional user-supplied title (e.g., "Refactor auth module").
    public let title: String?
    /// Optional error detail when `state` is `.failed` or `.cancelled`.
    public let errorMessage: String?

    public init(
        id: UUID,
        conversationID: UUID,
        parentTurnID: UUID? = nil,
        triggerMessageID: UUID? = nil,
        state: AgentTurnState,
        startedAt: Date,
        endedAt: Date? = nil,
        inputTokenCount: Int = 0,
        outputTokenCount: Int = 0,
        toolCallCount: Int = 0,
        toolCallCompletedCount: Int = 0,
        title: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.parentTurnID = parentTurnID
        self.triggerMessageID = triggerMessageID
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.toolCallCount = toolCallCount
        self.toolCallCompletedCount = toolCallCompletedCount
        self.title = title
        self.errorMessage = errorMessage
    }

    /// Total token usage (input + output).
    public var totalTokenCount: Int { inputTokenCount + outputTokenCount }

    /// Duration in seconds from `startedAt` to `endedAt` (or `startedAt` if still open).
    public var duration: TimeInterval {
        (endedAt ?? startedAt).timeIntervalSince(startedAt)
    }

    /// Whether this turn is in a terminal state.
    public var isFinished: Bool {
        switch state {
        case .completed, .failed, .cancelled: return true
        case .idle, .running, .suspended: return false
        }
    }
}
