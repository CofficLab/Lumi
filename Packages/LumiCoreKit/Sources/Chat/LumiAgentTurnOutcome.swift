import Foundation

/// `runAgentTurn` 结束时的结果，用于区分正常完成与等待用户回答。
public enum LumiAgentTurnOutcome: Sendable, Equatable {
    case completed
    case awaitingUserResponse
}
