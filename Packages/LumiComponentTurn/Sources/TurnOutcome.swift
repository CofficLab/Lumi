import Foundation

/// `runAgentTurn` 结束时的结果，用于区分正常完成、失败与等待用户回答。
public enum TurnOutcome: Sendable, Equatable {
    case completed
    case failed
    case awaitingUserResponse

    public var turnEndReason: LumiTurnEndReason {
        switch self {
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .awaitingUserResponse:
            return .awaitingUserResponse
        }
    }
}
