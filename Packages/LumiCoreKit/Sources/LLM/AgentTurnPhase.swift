import Foundation

/// Agent 回合在数据库中的阶段状态。
public enum AgentTurnPhase: String, Codable, Sendable, Equatable {
    /// 无进行中的 Turn
    case idle
    /// Turn 进行中
    case processing
    /// 等待工具权限授权
    case awaitingPermission
    /// 等待用户回答（如 ask_user）
    case awaitingUserResponse

    public init(storedValue: String?) {
        guard let storedValue,
              let phase = AgentTurnPhase(rawValue: storedValue) else {
            self = .idle
            return
        }
        self = phase
    }
}
