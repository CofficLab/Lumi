import Foundation

// MARK: - Agent Turn Types
//
// 值类型与枚举，与 `AgentTurnManaging` 协议（位于 `Providers/AgentTurnManaging.swift`）
// 配套使用。这些类型描述 agent turn 的生命周期、挂起、恢复与控制信号。
// 相关错误类型 `AgentTurnManagingError` 已在 `Errors/AgentTurnManagingError.swift` 中导出。

/// The lifecycle state of an agent turn managed by the kernel.
public enum AgentTurnState: Sendable, Equatable {
    case idle
    case running
    case suspended(AgentTurnSuspension)
    case completed
    case failed
    case cancelled
}

/// Persistable information describing why a turn is waiting and how it can resume.
public struct AgentTurnSuspension: Codable, Sendable, Equatable {
    public let suspensionID: String
    public let conversationID: UUID
    public let toolCallID: String?
    public let kind: String
    public let payload: String

    public init(
        suspensionID: String,
        conversationID: UUID,
        toolCallID: String? = nil,
        kind: String,
        payload: String
    ) {
        self.suspensionID = suspensionID
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.kind = kind
        self.payload = payload
    }
}

/// The user/plugin-provided value used to resume a suspended turn.
public struct AgentTurnResumeRequest: Sendable, Equatable {
    public let suspensionID: String
    public let answer: String

    public init(suspensionID: String, answer: String) {
        self.suspensionID = suspensionID
        self.answer = answer
    }
}

/// Work owned by a parent turn that may complete after the parent has
/// suspended. The manager starts this work only after the parent suspension has
/// been persisted, then resumes the parent with the returned answer.
public typealias AgentTurnChildWork = @MainActor @Sendable () async -> String

/// Control signal returned alongside a tool result.
public enum AgentTurnControl: Codable, Sendable, Equatable {
    case continueTurn
    case suspend(AgentTurnSuspension)
    case resumed(AgentTurnSuspension, answer: String)

    public var isSuspended: Bool {
        if case .suspend = self { return true }
        return false
    }

    public var isUserInteraction: Bool {
        switch self {
        case .suspend, .resumed:
            return true
        case .continueTurn:
            return false
        }
    }

    public var answer: String? {
        guard case let .resumed(_, answer) = self else { return nil }
        return answer
    }
}

public extension LumiToolCall {
    /// Whether this tool call has a result that no longer requires external
    /// interaction. A suspended interaction has a result payload, but it is
    /// not terminal until it is answered.
    var hasTerminalResult: Bool {
        guard let result else { return false }
        return !result.turnControl.isSuspended
    }
}

public extension Collection where Element == LumiToolCall {
    /// Whether every call in this assistant batch can be sent to the LLM as a
    /// completed tool-result sequence.
    var isTerminalToolBatch: Bool {
        allSatisfy(\.hasTerminalResult)
    }
}
