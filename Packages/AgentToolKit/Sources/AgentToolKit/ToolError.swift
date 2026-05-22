import Foundation

/// 工具执行错误
///
/// 定义工具执行过程中可能发生的错误类型。
public enum ToolError: LocalizedError {
    /// 工具未找到
    case toolNotFound(String)

    /// 工具执行失败
    case toolExecutionFailed(String, Error)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .toolExecutionFailed(let name, let error):
            return "Tool '\(name)' execution failed: \(error.localizedDescription)"
        }
    }
}
