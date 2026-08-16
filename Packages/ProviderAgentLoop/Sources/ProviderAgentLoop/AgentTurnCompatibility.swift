import Foundation

// MARK: - 原 ProviderAgentTurn 兼容层

/// 原 `ProviderAgentTurn` 包已合并进 `ProviderAgentLoop`：
/// `AgentTurnProviding` 协议并入 `AgentLoopProviding`（见 AgentLoopProviding.swift），
/// 以下类型仅为既有 UI/展示层兼容保留，新代码请直接使用 AgentLoop 类型。

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
