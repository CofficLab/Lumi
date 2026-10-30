import Foundation

public enum AgentLoopOutcome: Sendable, Equatable {
    case completed
    case failed(String)
    case cancelled
    case suspended(String)

    /// 回合是否已经到达终态。
    ///
    /// 终态意味着「这个回合不会再产出任何东西」：完成、失败、被取消。
    /// 挂起（`.suspended`）**不是**终态——回合还活着，只是停在等用户回答
    /// 或等工具授权的地方，恢复后会再次跑起来。
    ///
    /// 消费方（如消息发送器的待发队列）据此决定何时可以放行下一条消息：
    /// 只有终态才允许排空队列，挂起必须继续等。
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .suspended:
            return false
        }
    }
}
