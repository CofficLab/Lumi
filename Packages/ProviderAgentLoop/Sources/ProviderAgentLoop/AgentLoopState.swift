import Foundation

public enum AgentLoopState: String, Codable, Sendable {
    case idle
    case running
    case suspended
    case completed
    case failed
    case cancelled
}
