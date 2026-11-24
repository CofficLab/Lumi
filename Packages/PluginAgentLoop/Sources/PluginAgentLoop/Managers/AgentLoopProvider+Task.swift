import Foundation

// MARK: - Task Management

extension AgentLoopManager {
    /// 检查指定会话的回合是否正在运行。
    public func isRunning(for conversationID: UUID) -> Bool {
        runtimes[conversationID]?.isRunning ?? false
    }

    /// 取消后等到回合任务彻底结束才返回。
    ///
    /// `cancelTurn(in:)` 只发出取消信号：正在等待 LLM 的任务要到 Provider 返回
    /// 才会退出，期间仍可能写消息；终态事件也是异步投递的。需要在取消后立刻
    /// 改写时间线的调用方（编辑并重发）必须等这里返回，否则新写入的消息会被
    /// 迟到的写回覆盖或穿插，观察者也可能还没收到 `.cancelled`。
    /// 工具执行阶段和挂起回合没有常驻任务，取消本身是同步完成的。
    public func cancelTurnAndWait(in conversationID: UUID) async {
        // cancelTurn 会把 task 置空，必须先取句柄。
        let task = runtimes[conversationID]?.task
        cancelTurn(in: conversationID)
        // 终态通知任务由 cancelTurn 内部的 finishTurn 创建，取消之后才存在。
        let notificationTask = runtimes[conversationID]?.terminalNotificationTask
        await task?.value
        await notificationTask?.value
    }
}
