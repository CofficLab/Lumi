import Foundation

/// Agent 会话当前所处的 Turn 阶段。
public enum AgentTurnPhase: String, Sendable, Equatable, Codable {
  case idle
  case processing
  case awaitingPermission
  case awaitingUserResponse
}
