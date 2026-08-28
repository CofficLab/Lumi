import Foundation

public enum AgentLoopOutcome: Sendable, Equatable {
    case completed
    case failed(String)
    case cancelled
    case suspended(String)
}
