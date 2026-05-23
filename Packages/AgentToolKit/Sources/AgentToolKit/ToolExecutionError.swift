import Foundation

/// 工具执行错误
public enum ToolExecutionError: Error, LocalizedError {
    /// 工具未找到
    case toolNotFound(toolName: String)
    /// 执行失败
    case executionFailed(toolName: String, reason: String)
    /// 权限被拒绝
    case permissionDenied(toolName: String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let toolName):
            return "Tool '\(toolName)' not found."
        case .executionFailed(let toolName, let reason):
            return "Failed to execute '\(toolName)': \(reason)"
        case .permissionDenied(let toolName):
            return "Permission denied for '\(toolName)'"
        }
    }
}
