import Foundation
import ProviderAgentLoop

/// 会话列表需要的最小「停止回合」能力边界。
///
/// 列表只关心两件事：
/// - 「这个会话现在能不能停」（回合 running / suspended）；
/// - 「把它停掉」。
///
/// 它不直接持有 `AgentLoopProviding` 宽接口——由
/// `ConversationStopCapabilityAdapter` 负责收窄。
@MainActor
protocol ConversationStopCapability: AnyObject {
    /// 该会话当前是否可以被停止。
    ///
    /// 判定口径与 `ConversationStateSnapshot.canStop` 一致：
    /// 回合正在运行（`.running`），或挂在等工具授权 / 等用户回答（`.suspended`）
    /// 时才算「还有没干完的活」。其余终态（idle / completed / failed / cancelled）
    /// 都不可停止。
    func canStop(conversationID: UUID) -> Bool

    /// 停止该会话正在运行 / 挂起的回合。
    ///
    /// - Important: 取消权归 AgentLoop 回合状态机，`cancelTurn` 自身幂等，
    ///   没有活回合时就是 no-op，调用方无需先判断再决定要不要调。
    func stop(conversationID: UUID)
}

/// 将内核的 `AgentLoopProviding` 收窄为会话列表所需的停止能力。
@MainActor
final class ConversationStopCapabilityAdapter: ConversationStopCapability {
    // Provider 的生命周期归 Kernel 管理，Adapter 只借用。
    private weak var agentLoop: (any AgentLoopProviding)?

    init(agentLoop: (any AgentLoopProviding)?) {
        self.agentLoop = agentLoop
    }

    func canStop(conversationID: UUID) -> Bool {
        guard let agentLoop else { return false }
        let state = agentLoop.state(for: conversationID)
        return state == .running || state == .suspended
    }

    func stop(conversationID: UUID) {
        agentLoop?.cancelTurn(in: conversationID)
    }
}
