import Foundation

// MARK: - Task Management

extension AgentLoopProvider {
    /// 检查指定会话的回合是否正在运行。
    public func isRunning(for conversationID: UUID) -> Bool {
        tasks[conversationID] != nil || states[conversationID] == .running
    }
}
