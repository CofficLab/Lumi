import Foundation

// MARK: - Task Management

extension AgentLoopManager {
    /// 检查指定会话的回合是否正在运行。
    public func isRunning(for conversationID: UUID) -> Bool {
        runtimes[conversationID]?.isRunning ?? false
    }
}
