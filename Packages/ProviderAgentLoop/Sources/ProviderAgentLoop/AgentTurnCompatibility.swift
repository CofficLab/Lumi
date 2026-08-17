import Foundation

/// 原 `AgentTurnRequest`：显式开启一个回合的入参。
public struct AgentTurnRequest: Sendable {
    public let conversationID: UUID
    public let prompt: String

    public init(conversationID: UUID, prompt: String) {
        self.conversationID = conversationID
        self.prompt = prompt
    }
}

/// 原 `AgentTurnHandle`：`createTurn` 返回的回合句柄。
public struct AgentTurnHandle: Sendable, Equatable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// 兼容别名：UI 层仍可写 `AgentTurnState`（含 `suspended`）。
public typealias AgentTurnState = AgentLoopState

/// 兼容别名：UI 层仍可写 `AgentTurnOutcome`。
public typealias AgentTurnOutcome = AgentLoopOutcome
