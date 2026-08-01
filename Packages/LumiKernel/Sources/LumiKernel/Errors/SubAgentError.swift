import Foundation

/// 由 sub-agent 的工具调用层（包括 `SubAgentDelegateTool`、`SubAgentLoopRunner`
/// 等）抛出的领域错误。子智能体相关非错误类型保持在
/// `Types/Tools/SubAgentDelegateTool.swift`。
public enum SubAgentError: Error, Sendable {
    case missingArgument(String)
}
