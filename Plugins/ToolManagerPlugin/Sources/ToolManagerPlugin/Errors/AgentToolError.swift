import Foundation

/// Agent 工具错误
public enum AgentToolError: Error, LocalizedError {
    case toolNotFound(name: String)
    case executionFailed(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .executionFailed(let name, let reason):
            return "Tool '\(name)' execution failed: \(reason)"
        }
    }
}
